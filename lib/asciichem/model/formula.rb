# frozen_string_literal: true

module AsciiChem
  module Model
    # Top-level container: the root of every AsciiChem parse.
    class Formula < Node
      attr_accessor :nodes

      def initialize(nodes: [])
        @nodes = nodes
      end

      def <<(node)
        nodes << node
        self
      end

      def value_attributes
        { nodes: nodes }
      end

      def to_s
        "Formula[#{nodes.map(&:to_s).join(', ')}]"
      end
    end
  end
end
