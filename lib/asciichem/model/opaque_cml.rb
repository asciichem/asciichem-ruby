# frozen_string_literal: true

module AsciiChem
  module Model
    # An opaque carrier for CML elements that AsciiChem has no native
    # model class for (e.g. `<table>`, `<potential>`, `<band>`).
    # Preserves the raw XML through round-trip so documents with mixed
    # known/unknown content survive without loss.
    #
    # Has no AsciiChem text syntax. The Text formatter renders a
    # warning comment; round-trip via text loses the content
    # gracefully. Round-trip via CML preserves it.
    class OpaqueCml < Node
      attr_accessor :element_name, :raw_xml

      def initialize(element_name:, raw_xml:)
        @element_name = element_name
        @raw_xml = raw_xml
      end

      def value_attributes
        { element_name: element_name, raw_xml: raw_xml }
      end

      def children
        []
      end

      def diagnostic_label
        "OpaqueCml(#{element_name})"
      end
    end
  end
end
