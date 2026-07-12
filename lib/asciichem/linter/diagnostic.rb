# frozen_string_literal: true

module AsciiChem
  module Linter
    # A single linter finding. `severity` is `:error`, `:warning`, or
    # `:info`. `node` is the model node the diagnostic refers to (may
    # be nil for global issues).
    Diagnostic = Struct.new(:severity, :message, :node, keyword_init: true) do
      def to_s
        "[#{severity}] #{message}"
      end
    end
  end
end
