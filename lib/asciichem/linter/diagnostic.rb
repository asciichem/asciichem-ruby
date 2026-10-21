# frozen_string_literal: true

module AsciiChem
  module Linter
    # `details` carries optional structured data behind the message
    # (e.g. BalanceCheck's per-element [reactants, products] counts)
    # for consumers that want the numbers, not the prose. Human-facing
    # output stays the message.
    Diagnostic = Struct.new(:severity, :message, :node, :details,
                            keyword_init: true) do
      def to_s
        context = node&.diagnostic_label
        if context
          "[#{severity}] #{context}: #{message}"
        else
          "[#{severity}] #{message}"
        end
      end
    end
  end
end
