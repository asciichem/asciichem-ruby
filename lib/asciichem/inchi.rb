# frozen_string_literal: true

module AsciiChem
  # Local identity derivation (TODO.v2 10; TODO.impl 48).
  #
  # The InChI algorithm is never reimplemented: engines wrap the IUPAC
  # reference software (the standalone `inchi-1` binary here). The pipe
  # is Model::Molecule → molfile → engine → InChI/InChIKey.
  #
  # Engines are opt-in: set `AsciiChem::Inchi.engine` (or pass one per
  # call). Without an engine every derivation raises EngineMissingError
  # with install guidance — no silent fallback.
  module Inchi
    autoload :BinaryEngine, 'asciichem/inchi/binary_engine'
    autoload :Engine, 'asciichem/inchi/engine'
    autoload :Identity, 'asciichem/inchi/identity'

    INSTALL_GUIDE = 'install the IUPAC InChI software ' \
                    '(https://www.inchi-trust.org/downloads/) and set ' \
                    'AsciiChem::Inchi.engine = AsciiChem::Inchi::BinaryEngine.new ' \
                    '(or pass bin: "path/to/inchi-1")'

    class << self
      attr_accessor :engine

      # Derives the identity of one molecule. Falls back to the
      # configured engine when none is passed; raises
      # EngineMissingError when neither exists.
      def identity_for(molecule, engine: nil)
        selected = engine || self.engine
        raise EngineMissingError, "no InChI engine configured — #{INSTALL_GUIDE}" if selected.nil?

        selected.identity(molecule)
      end
    end
  end
end
