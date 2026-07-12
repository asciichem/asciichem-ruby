# frozen_string_literal: true

module AsciiChem
  module Model
    # A bond between two adjacent nodes in a structural chain.
    class Bond < Node
      attr_accessor :kind

      KINDS = {
        single:    { ascii: "-",  mathml_entity: "-" },
        double:    { ascii: "=",  mathml_entity: "=" },
        triple:    { ascii: "#",  mathml_entity: "≡" },
        quadruple: { ascii: "##", mathml_entity: "≣" },
        wedge:     { ascii: ">-", mathml_entity: "↑" },
        hash:      { ascii: "-<", mathml_entity: "↓" },
        dative:    { ascii: "~>", mathml_entity: "→" },
        wavy:      { ascii: "~~", mathml_entity: "∼" }
      }.freeze

      def initialize(kind: :single)
        @kind = kind
      end

      def value_attributes
        { kind: kind }
      end

      def ascii
        KINDS.fetch(kind).fetch(:ascii)
      end

      def entity
        KINDS.fetch(kind).fetch(:mathml_entity)
      end

      def to_s
        "Bond(#{kind})"
      end
    end
  end
end
