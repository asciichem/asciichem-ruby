# frozen_string_literal: true

module AsciiChem
  module Structure
    # Adjacency → linear model nodes. Atoms are emitted in the
    # caller's creation order (a DFS order for parsers that walk
    # depth-first). The parser marks each edge's shape, and the
    # partition rides it: a consecutive chain bond becomes a `Bond`
    # token; a RING-closure edge becomes a pair of matching ring
    # digits (exactly the mechanism AsciiChem's own ring syntax uses);
    # every other non-consecutive edge roots a BRANCH — the side-tree
    # hanging off it emits as a parenthesised group at the parent,
    # with the branch-root binding in the structure walkers attaching
    # the leading bond back to the parent (so the flat stream resumes
    # from the root, and `C(=O)O` texts read as carbonyls instead of
    # the digit soup that mis-wired aspirin's ester oxygen).
    #
    # Ring digits are allocated 1..9 and reused only once the
    # previous interval (first endpoint .. second endpoint, in atom
    # order) has closed: `RingBonds` pairs digits by occurrence order
    # across the molecule, so overlapping intervals must never share
    # a digit.
    class Linearizer
      MAX_DIGIT = 9

      def initialize(atoms:, edges:)
        @atoms = atoms
        @edges = edges
        @close_at = Array.new(MAX_DIGIT, -1)
        @digits_for = Array.new(@atoms.length) { "" }
        @token_before = {}
        @branch_at = Hash.new { |hash, key| hash[key] = [] }
        @in_branch = {}
        @children = Hash.new { |hash, key| hash[key] = [] }
        @branch_edges = []
      end

      # Returns the node array (Atoms and Bonds interleaved) and
      # mutates the atoms' `ring_closures` with the allocated digits.
      def nodes
        partition_edges

        result = []
        @atoms.each_with_index do |atom, index|
          next if @in_branch[index]

          edge = @token_before[index]
          if index.positive? && edge
            result << AsciiChem::Model::Bond.new(kind: edge.kind || :single,
                                                 direction: edge.direction)
          end
          atom.ring_closures = @digits_for[index] unless @digits_for[index].empty?
          result << atom
          @branch_at[index].each { |branch| result << branch_group(branch) }
        end
        compensate_chirality(result)
        result
      end

      private

      # The branch-first emission permutes each chiral atom's ligand
      # order (branch trees read before continuations), and the SMILES
      # parity mark is defined over that order — flip the mark when
      # the reorder is an odd permutation, so the model carries the
      # SAME enantiomer it parsed.
      def compensate_chirality(nodes)
        position = {}
        walk = lambda do |list|
          list.each do |node|
            case node
            when AsciiChem::Model::Atom
              position[node.object_id] = position.length
            when AsciiChem::Model::Group, AsciiChem::Model::Molecule
              walk.call(node.nodes)
            end
          end
        end
        walk.call(nodes)

        neighbours = Hash.new { |hash, key| hash[key] = [] }
        @edges.each do |edge|
          neighbours[edge.from] << edge.to
          neighbours[edge.to] << edge.from
        end
        @atoms.each_with_index do |atom, index|
          next unless %w[TH1 TH2].include?(atom.chirality)

          old_order = neighbours[index].sort
          new_order = old_order.sort_by { |ligand| position[@atoms[ligand].object_id] }
          inversions = 0
          old_order.each_with_index do |value, i|
            ((i + 1)...old_order.length).each do |j|
              inversions += 1 if new_order.index(value) > new_order.index(old_order[j])
            end
          end
          next if inversions.even?

          atom.chirality = atom.chirality == 'TH1' ? 'TH2' : 'TH1'
        end
      end

      # Partition the edges by the parser's own shape marks — tokens
      # and digits first (so the chain map is complete), then the
      # branch trees. A branch edge inside another branch's tree emits
      # as a NESTED group (the tree emission walks it through
      # @children); only top-level branches render at the flat stream.
      def partition_edges
        branch_edges = []
        @edges.each do |edge|
          if edge.ring
            first, last = [edge.from, edge.to].minmax
            digit = allocate_digit(first, last)
            @digits_for[first] += digit
            @digits_for[last] += digit
          elsif edge.to - edge.from == 1
            @token_before[edge.to] = edge
            @children[edge.from] << edge
          elsif @atoms[edge.from].aromatic && @atoms[edge.to].aromatic
            # A span-jump inside an aromatic ring system (the
            # continuation after a branch) stays on its digit pair:
            # grouping it would split the ring's aromatic component
            # and the Kekulé projection would lose the ring.
            digit = allocate_digit(edge.from, edge.to)
            @digits_for[edge.from] += digit
            @digits_for[edge.to] += digit
          else
            branch_edges << edge
          end
        end
        branch_edges.each do |edge|
          collect_branch(edge.to)
          @children[edge.from] << edge
        end
        @branch_edges = branch_edges
        branch_edges.each do |edge|
          @branch_at[edge.from] << edge unless @in_branch[edge.from]
        end
      end

      # Marks the branch tree's atoms (everything reachable from
      # `start` through chain bonds) for group emission.
      def collect_branch(start)
        @in_branch[start] = true
        @children[start].each { |edge| collect_branch(edge.to) }
      end

      # The branch's group: the leading bond, then the tree's atoms in
      # walk order with their chain tokens.
      def branch_group(edge)
        nodes = [AsciiChem::Model::Bond.new(kind: edge.kind || :single,
                                            direction: edge.direction)]
        emit_tree(edge.to, nodes)
        AsciiChem::Model::Group.new(bracket: :paren, nodes: nodes)
      end

      def emit_tree(atom_index, nodes)
        atom = @atoms[atom_index]
        atom.ring_closures = @digits_for[atom_index] unless @digits_for[atom_index].empty?
        nodes << atom
        # Branch groups sit directly after their parent atom (the
        # walkers bind a group's leading bond to the atom before it —
        # emitting a continuation first would steal the binding).
        @children[atom_index].each do |edge|
          nodes << branch_group(edge) if @branch_edges.include?(edge)
        end
        @children[atom_index].each do |edge|
          next if @branch_edges.include?(edge)

          nodes << AsciiChem::Model::Bond.new(kind: edge.kind || :single,
                                              direction: edge.direction)
          emit_tree(edge.to, nodes)
        end
      end

      def allocate_digit(first, last)
        digit_index = (0...MAX_DIGIT).find { |d| @close_at[d] <= first }
        unless digit_index
          raise AsciiChem::ParseError,
                "more than #{MAX_DIGIT} overlapping non-adjacent bonds — " \
                "beyond the model's ring-closure digit capacity"
        end
        @close_at[digit_index] = last
        (digit_index + 1).to_s
      end
    end
  end
end
