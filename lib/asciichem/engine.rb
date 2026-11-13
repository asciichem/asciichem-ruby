# frozen_string_literal: true

module AsciiChem
  # The parse engine: the PARG artifact engine, period (TODO.v2/17
  # slice 9; the maintainer's PARG-only directive). The legacy
  # parslet and DSL-parsanol engines are deleted — the checksummed
  # AsciiChem PARG artifact (vendored at engine/parg/asciichem.json,
  # sourced from asciichem-grammar) is the one grammar, and
  # PargEngine adapts its tree to the DSL shapes TransformRules
  # consumes.
  module Engine
    class Error < AsciiChem::Error; end

    # The engine is the PARG runtime; its gem must be installed.
    class NotAvailableError < Error; end

    autoload :PargEngine, 'asciichem/engine/parg_engine'
  end
end
