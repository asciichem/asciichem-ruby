# frozen_string_literal: true

module AsciiChem
  module Model
    # A multi-step reaction cascade: an ordered list of Reaction
    # objects where each step's products are the next step's
    # reactants. Source spelling is a chain of arrows:
    #
    #   A -> B -> C -> D
    #
    # Single-step reactions stay as `Reaction`; only multi-step
    # sequences promote to `ReactionCascade`.
    class ReactionCascade < Node
      attr_accessor :steps

      def initialize(steps:)
        @steps = steps
      end

      def value_attributes
        { steps: steps }
      end

      def children
        steps
      end

      def to_s
        "ReactionCascade(#{steps.map(&:to_s).join(' >> ')})"
      end
    end
  end
end
