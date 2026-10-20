# frozen_string_literal: true

module AsciiChem
  module Smiles
    # Model molecule → deterministic SMILES.
    #
    # Deterministic rules (not a canonical-rank algorithm):
    # - DFS from the first atom.
    # - At each atom: ring-closure digits first, then branches
    #   (sorted), then the continuation chain.
    # - The continuation child is chosen by: single/aromatic bond
    #   first (multiple bonds become branches, the way chemists write
    #   SMILES), then the largest unvisited subtree, then the lowest
    #   index.
    # - Ring digits are assigned in encounter order (1..9).
    #
    # The stability property `write(parse(write(x))) == write(x)` and
    # structural round-tripping are spec'd. Wedge/hash/dative/wavy
    # bonds and formula-only molecules raise.
    class Writer
      LOWERCASE_AROMATIC = %w[C N O S P B Se As].freeze
      ORGANIC = %w[B C N O P S F Cl Br I].freeze
      BOND_TOKENS = {
        single: '-', double: '=', triple: '#', quadruple: '$', aromatic: ':'
      }.freeze
      CONTINUATION_BONDS = %i[single aromatic].freeze

      def initialize(molecule)
        @molecule = molecule
      end

      def write
        atoms, edges = Structure::Graph.build(@molecule)
        # A single-atom component is valid SMILES (water "O", ions);
        # multiple atoms with no bonds is a formula, not a structure.
        raise ParseError, 'molecule has no bonds — a formula is not a structure' if edges.empty? && atoms.length > 1

        @atoms = atoms
        build_adjacency(edges)
        @visited = {}
        @digits = Array.new(atoms.length) { [] }
        @digit_by_edge = {}
        @next_digit = 1
        # Emission builds ordered units (atoms, literals); ring digits
        # attach to per-atom lists so both endpoints carry them
        # without string surgery.
        @units = []
        @tree_children = Array.new(atoms.length) { [] }
        @closures = Array.new(atoms.length) { [] }
        @tree_size = Array.new(atoms.length, 1)

        build_tree(0, nil)
        compute_tree_size(0)
        compute_written_orders
        emit(0, nil, nil)

        @units.map do |unit|
          if unit.first == :atom
            index = unit.last
            atom_token(index) + @digits[index].join
          else
            unit.last
          end
        end.join
      end

      private

      def build_adjacency(edges)
        @adjacency = Array.new(@atoms.length) { {} }
        @directions = {}
        @model_neighbours = Array.new(@atoms.length) { [] }
        edges.each do |edge|
          key = [edge.from, edge.to]
          @adjacency[edge.from][edge.to] = edge.kind
          @adjacency[edge.to][edge.from] = edge.kind
          key = key.minmax
          @directions[key] = edge.direction if edge.direction
          # The edge array is in model node order: each atom's
          # reference neighbours, for SMILES parity bookkeeping.
          @model_neighbours[edge.from] << edge.to
          @model_neighbours[edge.to] << edge.from
        end
      end

      # The order neighbours are WRITTEN in: parent first, then ring
      # closures, then branches (rank order), then the continuation.
      # Tetrahedral parity flips with odd permutations of this order
      # against the model's reference order, so the emitted @/@@ is
      # corrected per atom. Ring-closure neighbours in the reference
      # order are slice-3 scope (acyclic stereo is corrected here).
      def compute_written_orders
        @written_order = Array.new(@atoms.length)
        walk = lambda do |index, parent|
          order = parent ? [parent] : []
          order += @closures[index].dup
          # Appearance order: branches (rank order), then the
          # continuation — emit() writes them that way.
          ordered = @tree_children[index].sort_by { |child| continuation_rank(index, child) }
          order += ordered[1..] + [ordered.first] unless ordered.empty?
          @written_order[index] = order
          @tree_children[index].each { |child| walk.call(child, index) }
        end
        walk.call(0, nil)
      end

      # TH1 -> TH2 flip when the written order is an odd permutation
      # of the model's reference order (implicit hydrogens sort first
      # on both sides).
      def chirality_token(index)
        chirality = @atoms[index].chirality
        return '' unless chirality

        reference = ([:h] if @atoms[index].hydrogens) || []
        reference += @model_neighbours[index]
        written = ([:h] if @atoms[index].hydrogens) || []
        written += @written_order[index]
        inversions = 0
        written.each_with_index do |item, i|
          written[(i + 1)..].each do |later|
            inversions += 1 if reference.index(item) > reference.index(later)
          end
        end
        chirality == 'TH2' || inversions.odd? ? '@@' : '@'
      end

      # Post-order subtree sizes within the DFS tree.
      def compute_tree_size(index)
        @tree_children[index].each { |child| compute_tree_size(child) }
        @tree_size[index] = 1 + @tree_children[index].sum { |child| @tree_size[child] }
      end

      # First pass: a deterministic DFS tree. Children are visited in
      # index order; edges to already-visited atoms become closure
      # digits. Recording the tree first means a branch can never
      # walk around a ring and swallow the continuation atom.
      def build_tree(index, parent)
        @visited[index] = true
        @adjacency[index].keys.sort.each do |nb|
          if nb != parent && @visited[nb]
            @closures[index] << nb
          else
            next if @visited[nb]

            @tree_children[index] << nb
            build_tree(nb, index)
          end
        end
      end

      def emit(index, parent, incoming_kind)
        @units << [:literal, bond_token(incoming_kind, parent, index)] if parent
        @units << [:atom, index]
        @closures[index].each { |nb| ring_digit_for(index, nb) }

        children = @tree_children[index]
        return if children.empty?

        ordered = children.sort_by { |child| continuation_rank(index, child) }
        continuation, *branches = ordered

        branches.each do |child|
          @units << [:literal, '(']
          emit(child, index, @adjacency[index][child])
          @units << [:literal, ')']
        end
        emit(continuation, index, @adjacency[index][continuation])
      end

      # Lower sorts first: single/aromatic bonds continue the chain,
      # then larger subtrees, then the lexicographically smallest atom
      # token (order-independent, so the canonical form does not
      # depend on how the input happened to number the atoms).
      def continuation_rank(index, child)
        kind = @adjacency[index][child]
        priority = CONTINUATION_BONDS.include?(kind) ? 0 : 1
        # The order-independent token: this rank runs inside the
        # written-order pre-pass, where stereo tokens are not yet
        # computable (and stereo does not affect the order).
        [priority, -@tree_size[child], atom_token_for(child, stereo: false)]
      end

      def ring_digit_for(a, b)
        key = [a, b].minmax
        digit = @digit_by_edge[key]
        return digit if digit

        raise ParseError, 'too many ring closures for SMILES output' if @next_digit > 9

        digit = @next_digit.to_s
        @next_digit += 1
        @digit_by_edge[key] = digit
        # Both atom tokens carry the digit; each endpoint's list
        # receives it in encounter order.
        @digits[key.first] << digit
        @digits[key.last] << digit
        digit
      end

      def bond_token(kind, from, to)
        token = BOND_TOKENS[kind]
        raise ParseError, "#{kind} bonds have no SMILES form (v1 subset)" unless token

        return token if kind != :single && kind != :aromatic

        if kind == :single
          direction = @directions[[from, to].minmax]
          return direction == :up ? '/' : '\\' if direction

          return '' unless aromatic?(from) && aromatic?(to)

          # Explicit only when the short form would change the meaning:
          # a single bond between two aromatic atoms must be written.
          token
        else
          aromatic?(from) && aromatic?(to) ? '' : token
        end
      end

      def atom_token(index)
        atom_token_for(index, stereo: true)
      end

      # `stereo: false` gives the order-independent form for ranking
      # comparisons; the emitted token carries the corrected @/@@.
      def atom_token_for(index, stereo:)
        @plain_tokens ||= {}
        return @plain_tokens[index] if !stereo && @plain_tokens[index]

        atom = @atoms[index]
        aromatic = atom.aromatic == true
        lowercase = aromatic && LOWERCASE_AROMATIC.include?(atom.element)
        needs_bracket =
          atom.charge || atom.isotope || atom.hydrogens || atom.chirality ||
          (!ORGANIC.include?(atom.element) && !lowercase) ||
          (aromatic && !lowercase)
        token =
          if needs_bracket
            symbol = lowercase ? atom.element.downcase : atom.element
            t = +'['
            t << atom.isotope if atom.isotope
            t << symbol
            t << chirality_token(index) if stereo && atom.chirality
            if atom.hydrogens
              t << 'H'
              t << atom.hydrogens.to_s if atom.hydrogens > 1
            end
            t << charge_suffix(atom.charge) if atom.charge
            t << ']'
          else
            bare_symbol(atom, lowercase)
          end
        @plain_tokens[index] = token unless stereo
        token
      end

      def bare_symbol(atom, lowercase)
        lowercase ? atom.element.downcase : atom.element
      end

      # The model's number-then-sign charge ("2+") → SMILES ("+2").
      def charge_suffix(charge)
        count = charge[/\A\d+/]
        sign = charge[-1]
        return sign unless count && count.to_i > 1

        "#{sign}#{count}"
      end

      def aromatic?(index)
        @atoms[index].aromatic == true
      end
    end
  end
end
