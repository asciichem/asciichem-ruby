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

      # CML wire order codes per bond kind. Single source of truth
      # for both adapter directions — to_canonical emits, from_canonical
      # parses. Adding a new bond kind = one entry here + one in KINDS.
      CML_ORDER_CODES = {
        single: "S", double: "D", triple: "T",
        quadruple: "Q", wedge: "W", hash: "H",
        dative: "A", wavy: "V"
      }.freeze
      KIND_BY_CML_ORDER = CML_ORDER_CODES.invert.freeze

      # Subset that carries stereo meaning (wedge = out of page,
      # hash = into page). Used for <bondStereo> elements.
      CML_STEREO_CODES = { wedge: "W", hash: "H" }.freeze

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

      def cml_order_code
        CML_ORDER_CODES.fetch(kind, "S")
      end

      def cml_stereo_code
        CML_STEREO_CODES.fetch(kind)
      end

      def to_s
        "Bond(#{kind})"
      end
    end
  end
end
