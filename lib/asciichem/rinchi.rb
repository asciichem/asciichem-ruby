# frozen_string_literal: true

module AsciiChem
  # Reaction identity via RInChI (TODO.v2/13 item 4; TODO.v2/10 pattern).
  #
  # Like InChI, the algorithm is never reimplemented. Two layers share
  # this module, one per transport:
  #
  # - **Per-molecule identities** (the drawn reaction in the model):
  #   engines wrap the IUPAC RInChI software (`rinchi-1`). The pipe is
  #   Model::Reaction → RXN → engine → RInChI keys. Engines are
  #   opt-in: set `AsciiChem::Rinchi.engine` (or pass one per call).
  #   Without an engine every derivation raises EngineMissingError
  #   with install guidance — no silent fallback.
  # - **The reaction-identity surface** (the chemomer engine's RInChI
  #   layer, mirroring asciichem::rinchi): a recorded reaction's
  #   RXNfile/RDfile text derives the five identity lines, and a
  #   RInChI string decodes back into its components. The transport
  #   is the chemomer cdylib through its C ABI
  #   (`Rinchi::NativeEngine`, CHEMOMER_LIB) — the same opt-in
  #   posture as the identity derivation's native engine.
  module Rinchi
    autoload :BinaryEngine, 'asciichem/rinchi/binary_engine'
    autoload :Identity, 'asciichem/rinchi/identity'
    autoload :NativeEngine, 'asciichem/rinchi/native_engine'
    autoload :Record, 'asciichem/rinchi/record'
    autoload :Component, 'asciichem/rinchi/reaction'
    autoload :Reaction, 'asciichem/rinchi/reaction'

    INSTALL_GUIDE = 'install the IUPAC RInChI software ' \
                    '(https://github.com/IUPAC-InChI/RInChI — build ' \
                    'src/example_apps/rinchi_cmdline against InChI v1.07.5) ' \
                    'and set AsciiChem::Rinchi.engine = ' \
                    'AsciiChem::Rinchi::BinaryEngine.new ' \
                    '(or pass bin: "path/to/rinchi_cmdline")'

    NATIVE_INSTALL_GUIDE = 'build the chemomer engine cdylib ' \
                           '(cargo build --release in the chemomer ' \
                           'checkout) and set CHEMOMER_LIB to its path'

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

      # -- the chemomer reaction-identity surface (the recorded
      #    bytes' derive/decode directions) --------------------------

      # Assembles a reaction's identity record from its V2000 RXNfile
      # text — the five engine-verbatim lines (identifier, RAuxInfo,
      # the three RInChIKey shapes).
      def derive_from_rxnfile(rxnfile, engine: nil)
        selected_engine(engine).derive_from_rxnfile(rxnfile)
      end

      # Assembles the identity record from an MDL RDfile (the RXN
      # block verbatim plus the `$DATUM $MFMT` agent scan). The C ABI
      # exports the identifier line only for this edge; the remaining
      # fields stay nil.
      def derive_from_rdfile(rdfile, engine: nil)
        selected_engine(engine).derive_from_rdfile(rdfile)
      end

      # Decodes a RInChI string (plus its RAuxInfo companion when
      # known) into the reaction it identifies — the components carry
      # their identities straight from the string; the direction flag
      # recovers which group held which role.
      def decode(rinchi, rauxinfo: '', engine: nil)
        selected_engine(engine).decode(rinchi, rauxinfo: rauxinfo)
      end

      private

      def selected_engine(engine)
        return engine if engine

        lib = NativeEngine.default_lib
        if lib.nil?
          raise EngineMissingError,
                "no chemomer native engine configured — #{NATIVE_INSTALL_GUIDE}"
        end

        NativeEngine.new(lib: lib)
      end
    end
  end
end
