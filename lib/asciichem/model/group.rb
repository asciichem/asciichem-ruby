# frozen_string_literal: true

module AsciiChem
  module Model
    # A parenthesised sub-formula with an outer multiplicity.
    class Group < Node
      attr_accessor :nodes, :multiplicity, :bracket

      def initialize(nodes:, multiplicity: nil, bracket: :paren)
        @nodes = nodes
        @multiplicity = multiplicity
        @bracket = bracket
      end

      def value_attributes
        { nodes: nodes, multiplicity: multiplicity, bracket: bracket }
      end

      def children
        nodes
      end

      def to_s
        open, close = brackets
        inner = nodes.map(&:to_s).join(", ")
        suffix = multiplicity ? "_#{multiplicity}" : ""
        "Group#{open}#{inner}#{close}#{suffix}"
      end

      def open_char
        brackets.first
      end

      def close_char
        brackets.last
      end

      private

      def brackets
        case bracket
        when :paren  then ["(", ")"]
        when :square then ["[", "]"]
        when :brace  then ["{", "}"]
        else ["(", ")"]
        end
      end
    end
  end
end
