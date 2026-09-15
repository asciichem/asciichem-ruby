# frozen_string_literal: true

module AsciiChem
  module Engine
    # The reference engine: pure-Ruby parslet. Zero extra
    # dependencies; Grammar and Transform as always.
    class ParsletEngine
      class << self
        def grammar
          Grammar
        end

        def transform
          Transform
        end

        def parse_failed
          Parslet::ParseFailed
        end

        # Engines memoize their grammar/transform instances — they are
        # stateless and expensive to construct (benchmark: ~15%
        # throughput on repeated parses).
        def grammar_instance
          @grammar_instance ||= grammar.new
        end

        def transform_instance
          @transform_instance ||= transform.new
        end
      end
    end
  end
end
