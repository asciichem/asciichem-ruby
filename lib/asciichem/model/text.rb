# frozen_string_literal: true

module AsciiChem
  module Model
    # A run of plain text — operators, whitespace, anything the grammar
    # doesn't promote to a typed node.
    class Text < Node
      attr_accessor :content

      def initialize(content:)
        @content = content
      end

      def value_attributes
        { content: content }
      end

      def to_s
        "Text(#{content.inspect})"
      end
    end
  end
end
