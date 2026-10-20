# frozen_string_literal: true

module AsciiChem
  module Smiles
    # Recursive-descent parser for the supported SMILES subset.
    # SMILES is a linear grammar, so a direct parser is clearer than
    # a parse-tree + transform round trip; it builds the model
    # through the shared Structure::Linearizer.
    #
    # v1 subset (each deferral raises an actionable ParseError):
    # chirality `@`/`@@`, E/Z bond directions `/` `\`, wildcard `*`,
    # reaction atom maps, queries.
    class Parser
      ORGANIC = %w[Cl Br B C N O P S F I].freeze
      AROMATIC = %w[se as b c n o p s].freeze

      def initialize(source)
        @source = source
        @pos = 0
      end

      # Returns a Model::Formula with one Molecule per dot component.
      def parse
        molecules = [component]
        molecules << component while eat('.')
        unless @pos == @source.length
          raise ParseError,
                "unexpected character #{peek.inspect} at position #{@pos} in #{@source.inspect}"
        end
        Model::Formula.new(nodes: molecules)
      end

      private

      def component
        @atoms = []
        @adjacency = []
        @edge_directions = {}
        @open_rings = {}
        @parent = nil
        @pending_kind = nil
        @pending_direction = nil

        chain

        unless @open_rings.empty?
          raise ParseError,
                "unclosed ring bond digit(s): #{@open_rings.keys.sort.join(', ')} in #{@source.inspect}"
        end

        edges = []
        @adjacency.each_with_index do |neighbors, index|
          neighbors.each do |to, kind|
            next unless to > index

            edges << Structure::Graph::Edge.new(
              from: index, to: to, kind: kind,
              direction: @edge_directions[[index, to]]
            )
          end
        end
        Model::Molecule.new(nodes: Structure::Linearizer.new(atoms: @atoms, edges: edges).nodes)
      end

      # chain := atom (bond? atom | branch | ringbond)*
      # Bare adjacency (no bond token) means a default bond.
      def chain
        atom_token
        until eoc?
          if peek == '('
            branch
          elsif bond_start?
            kind, direction = bond_token
            if peek == '('
              branch(kind, direction)
            elsif digit_start?
              ringbond(kind, direction)
            else
              @pending_kind = kind
              @pending_direction = direction
              atom_token
            end
          elsif digit_start?
            ringbond(nil)
          else
            @pending_kind = nil
            @pending_direction = nil
            atom_token
          end
        end
      end

      def branch(kind = nil, direction = nil)
        expect('(')
        # The bond may lead the branch ("C-(O)") or open it ("C(=O)").
        kind, direction = bond_token if kind.nil? && bond_start?
        saved_parent = @parent
        saved_pending = @pending_kind
        saved_direction = @pending_direction
        @pending_kind = kind
        @pending_direction = direction
        chain
        expect(')')
        @parent = saved_parent
        @pending_kind = saved_pending
        @pending_direction = saved_direction
      end

      def ringbond(kind, direction = nil)
        digit = ring_digit
        if direction
          raise ParseError,
                "directional ring closures (#{direction}) are not representable in the model's ring-closure form"
        end
        if @open_rings.key?(digit)
          opener = @open_rings.delete(digit)
          # The model's ring-closure digits carry no bond kind, so an
          # explicit kind that differs from the default (aromatic
          # between aromatic atoms, otherwise single) cannot be
          # represented — reject rather than silently downgrade.
          if kind && kind != default_kind(opener, @parent)
            raise ParseError,
                  "bonded ring closures (#{kind}) are not representable in the model's ring-closure form"
          end
          add_edge(opener, @parent, kind)
        else
          @open_rings[digit] = @parent
        end
      end

      def atom_token
        atom = read_atom
        index = @atoms.length
        @atoms << atom
        @adjacency[index] = {}
        if @parent
          add_edge(@parent, index, @pending_kind)
          @edge_directions[[@parent, index].minmax] = @pending_direction if @pending_direction
        end
        @parent = index
        @pending_kind = nil
        @pending_direction = nil
      end

      def add_edge(from, to, explicit)
        kind = explicit || default_kind(from, to)
        @adjacency[from][to] = kind
        @adjacency[to][from] = kind
      end

      def default_kind(from, to)
        @atoms[from].aromatic && @atoms[to].aromatic ? :aromatic : :single
      end

      # -- tokens ----------------------------------------------------------

      def read_atom
        return bracket_atom if peek == '['

        two = @source[@pos, 2].to_s
        if (symbol = ORGANIC.find { |s| two.start_with?(s) })
          @pos += symbol.length
          return Model::Atom.new(element: symbol)
        end
        if (symbol = AROMATIC.find { |s| two.start_with?(s) } || AROMATIC.find { |s| peek == s })
          @pos += symbol.length
          return Model::Atom.new(element: symbol.capitalize, aromatic: true)
        end

        raise ParseError, "unexpected character #{peek.inspect} at position #{@pos} in #{@source.inspect}"
      end

      def bracket_atom
        expect('[')
        isotope = digits
        symbol = bracket_symbol
        chirality = read_chirality
        hydrogens = hcount
        charge = bracket_charge
        skip_class
        expect(']')
        Model::Atom.new(
          element: symbol.capitalize,
          isotope: isotope,
          charge: charge,
          hydrogens: hydrogens,
          chirality: chirality,
          aromatic: symbol.match?(/\A[a-z]/) || nil
        )
      end

      AROMATIC_TWO_CHAR = %w[se as].freeze

      def bracket_symbol
        two = @source[@pos, 2].to_s
        if AROMATIC_TWO_CHAR.include?(two)
          @pos += 2
          return two
        end
        if @source[@pos] =~ /[bcnops]/
          sym = @source[@pos]
          @pos += 1
          return sym
        end
        if @source[@pos] =~ /[A-Z]/
          sym = @source[@pos]
          sym += @source[@pos + 1] if @source[@pos + 1] =~ /[a-z]/
          @pos += sym.length
          return sym
        end
        raise ParseError, "expected an element symbol at position #{@pos} in #{@source.inspect}"
      end

      # `@' (TH1) / `@@' (TH2): SMILES ordered-neighbour tetrahedral
      # parity, stored verbatim on the atom — the writer recomputes
      # the token for its own traversal order.
      def read_chirality
        return nil unless peek == '@'

        if @source[@pos, 2] == '@@'
          @pos += 2
          'TH2'
        else
          @pos += 1
          'TH1'
        end
      end

      def hcount
        return nil unless peek == 'H'

        @pos += 1
        count = digits
        count ? count.to_i : 1
      end

      # "+" | "++" | "+n" | "-" | "--" | "-n" → number-then-sign.
      def bracket_charge
        sign = peek
        return nil unless ['+', '-'].include?(sign)

        @pos += 1
        second = @source[@pos].to_s
        count =
          if second == sign
            @pos += 1
            2
          elsif second =~ /[0-9]/
            digits.to_i
          end
        count&.positive? ? "#{count}#{sign}" : sign
      end

      def skip_class
        return unless peek == ':'

        @pos += 1
        digits
      end

      # Returns [kind, direction]: `/' and `\' are DIRECTIONAL SINGLE
      # bonds (SMILES E/Z stereo) — kind stays :single, the direction
      # rides the model's Bond#direction.
      def bond_token
        ch = peek
        kind = { '-' => :single, '=' => :double, '#' => :triple, '$' => :quadruple,
                 ':' => :aromatic }[ch]
        unless kind
          if ['/', '\\'].include?(ch)
            @pos += 1
            return [:single, ch == '/' ? :up : :down]
          end
          raise ParseError, "expected a bond or atom at position #{@pos} in #{@source.inspect}"
        end
        @pos += 1
        [kind, nil]
      end

      def ring_digit
        if peek == '%'
          @pos += 1
          digit = @source[@pos, 2].to_s
          raise ParseError, 'malformed %nn ring closure' unless digit.match?(/\A\d\d\z/)

          @pos += 2
          digit
        else
          d = peek
          raise ParseError, "expected ring digit at position #{@pos}" unless d =~ /[0-9]/

          @pos += 1
          d
        end
      end

      # -- character helpers -------------------------------------------------

      def peek
        @source[@pos]
      end

      def digits
        start = @pos
        @pos += 1 while @source[@pos] =~ /[0-9]/
        @pos == start ? nil : @source[start...@pos]
      end

      def bond_start?
        %w[- = # $ : / \\].include?(peek)
      end

      def digit_start?
        peek =~ /[0-9%]/
      end

      def eoc?
        peek.nil? || %w[. )].include?(peek)
      end

      def eat(char)
        return false unless peek == char

        @pos += 1
        true
      end

      def expect(char)
        raise ParseError, "expected #{char.inspect} at position #{@pos} in #{@source.inspect}" unless peek == char

        @pos += 1
      end
    end
  end
end
