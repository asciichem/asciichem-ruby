# frozen_string_literal: true

module AsciiChem
  # Offline format validation for chemical identifier conventions
  # (CAS RN, InChI, InChIKey, SMILES sanity).
  #
  # Validators self-register via `register("cas")` in their class body;
  # this module eagerly triggers every autoload at load time so
  # registration runs before any API query (same pattern as Linter).
  #
  # Validation is purely lexical/checksum based. It never touches the
  # network and never decides whether an identifier is *assigned* to a
  # real substance — that is resolution (TODO.v2 07 Layer 2).
  module Identifiers
    autoload :Base, "asciichem/identifiers/base"
    autoload :Cas, "asciichem/identifiers/cas"
    autoload :Inchi, "asciichem/identifiers/inchi"
    autoload :Inchikey, "asciichem/identifiers/inchikey"
    autoload :Smiles, "asciichem/identifiers/smiles"

    class << self
      # The validator class for a convention (String or Symbol), or nil.
      def [](convention)
        registry[normalize(convention)]
      end

      # Whether a validator is registered for the convention. Unknown
      # conventions are not errors — they are simply not checkable
      # offline (e.g. `iupac`, `cid`, `chebi`).
      def known?(convention)
        registry.key?(normalize(convention))
      end

      def valid?(convention, value)
        validator = self[convention]
        !validator.nil? && validator.valid?(value)
      end

      # nil when the value is valid (or the convention is unknown);
      # a human-readable reason otherwise.
      def diagnostic(convention, value)
        self[convention]&.diagnostic(value)
      end

      # Extension point: called by Base.register. New convention =
      # one validator class + one registration, nothing else changes.
      def register(convention, validator)
        registry[normalize(convention)] = validator
      end

      private

      def registry
        @registry ||= {}
      end

      def normalize(convention)
        convention.to_s
      end
    end

    # Eagerly trigger every autoload so validators self-register at
    # module-load time, before any API query.
    constants.each { |name| const_get(name) }
  end
end
