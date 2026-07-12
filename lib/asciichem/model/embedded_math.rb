# frozen_string_literal: true

module AsciiChem
  module Model
    # A run of mathematics embedded in chemistry. Wraps a
    # `Plurimath::Math::Formula` so we never reinvent math typography.
    #
    # Source spelling: backtick-delimited, e.g. `` `K_c = [P]/[R]` ``.
    class EmbeddedMath < Node
      attr_accessor :formula, :source

      def initialize(formula:, source: nil)
        @formula = formula
        @source = source
      end

      def value_attributes
        { formula: formula, source: source }
      end

      def to_s
        "EmbeddedMath(#{source || formula.inspect})"
      end
    end
  end
end
