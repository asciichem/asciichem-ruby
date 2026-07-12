# frozen_string_literal: true

module AsciiChem
  module Model
    # A chemical reaction: reactants, an arrow, and products. Conditions
    # render above and below the arrow per IUPAC.
    class Reaction < Node
      Conditions = Struct.new(:above, :below, keyword_init: true)

      ARROWS = {
        forward:     { ascii: "->",   mathml_entity: "→" },
        reverse:     { ascii: "<-",   mathml_entity: "←" },
        equilibrium: { ascii: "<=>",  mathml_entity: "⇌" },
        resonance:   { ascii: "<->",  mathml_entity: "↔" }
      }.freeze

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

      def arrow_ascii
        ARROWS.fetch(arrow).fetch(:ascii)
      end

      def arrow_entity
        ARROWS.fetch(arrow).fetch(:mathml_entity)
      end

      def to_s
        "Reaction(#{reactants.map(&:to_s).join(' + ')} " \
          "#{arrow_ascii} #{products.map(&:to_s).join(' + ')})"
      end
    end
  end
end
