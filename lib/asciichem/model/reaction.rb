# frozen_string_literal: true

module AsciiChem
  module Model
    # A chemical reaction: reactants, an arrow, and products. Conditions
    # render above and below the arrow per IUPAC.
    class Reaction < Node
      Conditions = Struct.new(:above, :below, keyword_init: true)

      ARROWS = {
        forward:     { ascii: '->',   mathml_entity: '→', wire: 'forward' },
        reverse:     { ascii: '<-',   mathml_entity: '←', wire: 'reverse' },
        equilibrium: { ascii: '<=>',  mathml_entity: '⇌', wire: 'equilibrium' },
        resonance:   { ascii: '<->',  mathml_entity: '↔', wire: 'resonance' }
      }.freeze
      ARROW_BY_WIRE = ARROWS.to_h { |kind, attrs| [attrs[:wire], kind] }.freeze

      attr_accessor :reactants, :products, :arrow, :conditions

      def initialize(reactants:, products:, arrow: :forward, conditions: nil)
        @reactants = reactants
        @products = products
        @arrow = arrow
        @conditions = conditions || Conditions.new
      end

      def value_attributes
        { reactants: reactants, products: products, arrow: arrow,
          conditions: conditions }
      end

      def children
        reactants + products
      end

      def arrow_ascii
        ARROWS.fetch(arrow).fetch(:ascii)
      end

      def arrow_entity
        ARROWS.fetch(arrow).fetch(:mathml_entity)
      end

      # Wire name for CML serialisation (the value stored in
      # `<reaction type="..."/>`). Single source of truth for the
      # arrow wire format.
      def arrow_wire
        ARROWS.fetch(arrow).fetch(:wire)
      end

      # Inverse of arrow_wire: given a wire string from CML, return
      # the canonical arrow symbol. Falls back to :forward for
      # unrecognised or missing values (matches existing behaviour).
      def self.arrow_from_wire(wire)
        ARROW_BY_WIRE.fetch(wire&.to_s, :forward)
      end

      def to_s
        "Reaction(#{reactants.map(&:to_s).join(' + ')} " \
          "#{arrow_ascii} #{products.map(&:to_s).join(' + ')})"
      end
    end
  end
end
