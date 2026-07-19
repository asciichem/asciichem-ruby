# frozen_string_literal: true

module AsciiChem
  module Model
    # A reaction mechanism: multi-step pathway with spectators.
    #
    # Syntax:
    #   mechanism{
    #     step1: A + B -> C
    #     step2: C -> D + E
    #     spectator: Na+
    #   }
    class Mechanism < Node
      # A single step in the mechanism, identified by a label.
      Step = Struct.new(:label, :reaction, keyword_init: true)

      attr_accessor :steps, :spectators

      def initialize(steps: [], spectators: [])
        @steps = steps
        @spectators = spectators
      end

      def value_attributes
        { steps: steps, spectators: spectators }
      end

      def children
        []
      end

      def diagnostic_label
        "Mechanism(#{steps.length} steps)"
      end
    end
  end
end
