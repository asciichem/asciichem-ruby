# frozen_string_literal: true

module AsciiChem
  module Model
    # The adduct: the middle-dot connective between molecules at the
    # formula level (mhchem's A·B — `CuSO4 . 5H2O` hydrates, grammar
    # v0.9.0).
    #
    # N-ary, not a binary connective: the components map one-to-one
    # onto the InChI multi-component layers, and each component's
    # coefficient carries its multiplicity (`5H2O` parses as the
    # coefficient on the water molecule). The ASCII spelling is the
    # period with whitespace on both sides; the literal middle dot is
    # accepted as the mhchem alias — the canonical text emits the
    # ASCII ` . ` form.
    class Adduct < Node
      attr_accessor :components

      def initialize(components:)
        @components = components
      end

      def value_attributes
        { components: components }
      end

      def children
        components
      end

      def accept(visitor)
        visitor.visit_adduct(self)
      end

      def to_s
        "Adduct[#{components.map(&:to_s).join(' . ')}]"
      end
    end
  end
end
