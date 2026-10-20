# frozen_string_literal: true

module AsciiChem
  # Reaction identity via RInChI (TODO.v2/13 item 4; TODO.v2/10 pattern).
  #
  # Like InChI, the algorithm is never reimplemented: engines wrap the
  # IUPAC RInChI software (`rinchi-1`). The pipe is
  # Model::Reaction → RXN → engine → RInChI keys.
  #
  # Engines are opt-in: set `AsciiChem::Rinchi.engine` (or pass one
  # per call). Without an engine every derivation raises
  # EngineMissingError with install guidance — no silent fallback.
  module Rinchi
    autoload :BinaryEngine, 'asciichem/rinchi/binary_engine'
    autoload :Identity, 'asciichem/rinchi/identity'

    INSTALL_GUIDE = 'install the IUPAC RInChI software ' \
                    '(https://github.com/IUPAC-InChI/RInChI) and set ' \
                    'AsciiChem::Rinchi.engine = AsciiChem::Rinchi::BinaryEngine.new ' \
                    '(or pass bin: "path/to/rinchi-1")'

    class << self
      attr_accessor :engine

      # Derives the identity of one reaction. Falls back to the
      # configured engine when none is passed; raises
      # EngineMissingError when neither exists.
      def identity_for(reaction, engine: nil)
        selected = engine || self.engine
        raise EngineMissingError, "no RInChI engine configured — #{INSTALL_GUIDE}" if selected.nil?

        selected.identity(reaction)
      end
    end
  end
end
