# frozen_string_literal: true

module AsciiChem
  module Identifiers
    # InChIKey format validation: 27 uppercase letters in three blocks
    # of 14, 10, and 1, separated by hyphens (e.g.
    # BSYNRYMUTXBXSQ-UHFFFAOYSA-N for aspirin). Check-character
    # verification is left to the InChI engine (TODO.v2 10) — format
    # alone catches the common corruptions (case, block lengths,
    # misplaced hyphens).
    class Inchikey < Base
      register "inchikey"

      FORMAT = /\A[A-Z]{14}-[A-Z]{10}-[A-Z]\z/

      class << self
        def diagnostic(value)
          return type_message(value) unless value.is_a?(String)
          return nil if FORMAT.match?(value)

          "InChIKey #{value.inspect} must be 27 uppercase letters in " \
            "XXXXXXXXXXXXXX-XXXXXXXXXX-X form (blocks of 14, 10, and 1)"
        end

        private

        def type_message(value)
          "InChIKey must be a String, got #{value.class}"
        end
      end
    end
  end
end
