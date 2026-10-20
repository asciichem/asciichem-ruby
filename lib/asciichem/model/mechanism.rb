# frozen_string_literal: true

module AsciiChem
  module Model
    # A reaction mechanism: multi-step pathway with spectators.
    #
    # Syntax:
    #   mechanism{
    #     step1: A + B -> C
    #     step2: C -> D + E | flow: C > D; C-B > D
    #     spectator: Na+
    #   }
    #
    # A step's value is its reaction, optionally followed by
    # `| flow: SOURCE > TARGET` clauses (semicolon-separated) naming
    # the electron-flow arrows drawn for that step. Sources/targets
    # stay verbatim strings: an atom-level binding needs references
    # the mechanism text does not yet carry.
    class Mechanism < Node
      # One electron-flow marker within a step.
      Flow = Struct.new(:source, :target, keyword_init: true)

      # A single step in the mechanism, identified by a label.
      Step = Struct.new(:label, :reaction, :flows, keyword_init: true)

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
