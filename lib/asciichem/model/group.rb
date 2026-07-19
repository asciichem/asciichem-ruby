# frozen_string_literal: true

module AsciiChem
  module Model
    # A parenthesised sub-formula with an outer multiplicity.
    class Group < Node
      # Bracket kinds: open/close characters and the aci:wire name.
      # Single source of truth for "what bracket kinds exist, what
      # they look like, and how they serialise". GroupExtensions and
      # any future consumer reference these instead of inlining their
      # own case statements.
      BRACKETS = {
        paren:  { open: '(', close: ')', wire: 'paren'  },
        square: { open: '[', close: ']', wire: 'square' },
        brace:  { open: '{', close: '}', wire: 'brace'  }
      }.freeze
      BRACKET_BY_WIRE = BRACKETS.to_h do |kind, attrs|
        [attrs[:wire], kind]
      end.freeze

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
        open, close = bracket_chars
        inner = nodes.map(&:to_s).join(', ')
        suffix = multiplicity ? "_#{multiplicity}" : ''
        "Group#{open}#{inner}#{close}#{suffix}"
      end

      def open_char
        bracket_attrs.fetch(:open)
      end

      def close_char
        bracket_attrs.fetch(:close)
      end

      # Wire name for CML serialisation (GroupExtensions consumes).
      def wire_bracket
        bracket_attrs.fetch(:wire)
      end

      private

      def bracket_attrs
        BRACKETS.fetch(bracket, BRACKETS[:paren])
      end

      def bracket_chars
        [bracket_attrs.fetch(:open), bracket_attrs.fetch(:close)]
      end
    end
  end
end
