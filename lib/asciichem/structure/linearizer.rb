# frozen_string_literal: true

module AsciiChem
  module Structure
    # Adjacency → linear model nodes. Atoms are emitted in the
    # caller's creation order (a DFS order for parsers that walk
    # depth-first). An edge between consecutive atoms becomes a
    # `Bond` token; every other edge becomes a pair of matching ring
    # closure digits — exactly the mechanism AsciiChem's own ring
    # syntax uses, so downstream walkers (`RingBonds`, Layout,
    # ModelAdapter) see the graph with no new machinery.
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
      end

      # Returns the node array (Atoms and Bonds interleaved) and
      # mutates the atoms' `ring_closures` with the allocated digits.
      def nodes
        @edges.each do |edge|
          first, last = [edge.from, edge.to].minmax
          if last - first == 1
            @token_before[last] = edge.kind
          else
            digit = allocate_digit(first, last)
            @digits_for[first] += digit
            @digits_for[last] += digit
          end
        end

        result = []
        @atoms.each_with_index do |atom, index|
          kind = @token_before[index]
          result << AsciiChem::Model::Bond.new(kind: kind || :single) if index.positive? && kind
          atom.ring_closures = @digits_for[index] unless @digits_for[index].empty?
          result << atom
        end
        result
      end

      private

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
