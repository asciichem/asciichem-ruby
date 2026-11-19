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
        result
      end

      private

      # Partition the edges by the parser's own shape marks — tokens
      # and digits first (so the chain map is complete), then the
      # branch trees. A branch edge inside another branch's tree emits
      # as a NESTED group (the tree emission walks it through
      # @children); only top-level branches render at the flat stream.
      # Producers without shape marks (molfile, CML) ride the flat
      # rule: consecutive indices are chain tokens, every other
      # non-ring edge a digit pair — the pre-branch-projection shape
      # those producers were recorded against.
      def partition_edges
        branch_edges = []
        @edges.each do |edge|
          if edge.ring
            first, last = [edge.from, edge.to].minmax
            digit = allocate_digit(first, last)
            @digits_for[first] += digit
            @digits_for[last] += digit
          elsif edge.shape == :branch
            branch_edges << edge
          elsif edge.shape == :chain || (edge.shape.nil? && (edge.to - edge.from).abs == 1)
            @token_before[edge.to] = edge
            @children[edge.from] << edge
          else
            first, last = [edge.from, edge.to].minmax
            digit = allocate_digit(first, last)
            @digits_for[first] += digit
            @digits_for[last] += digit
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
