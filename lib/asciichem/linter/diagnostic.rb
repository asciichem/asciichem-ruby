# frozen_string_literal: true

module AsciiChem
  module Linter
    Diagnostic = Struct.new(:severity, :message, :node, keyword_init: true) do
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
