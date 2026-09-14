# frozen_string_literal: true

module AsciiChem
  class Error < StandardError; end

  class ParseError < Error; end

  class FormatError < Error; end

  # No InChI engine is configured (or the engine binary is absent).
  # Identity derivation is opt-in; the message always carries install
  # guidance (TODO.v2 10: never a silent fallback or homemade InChI).
  class EngineMissingError < Error; end
end
