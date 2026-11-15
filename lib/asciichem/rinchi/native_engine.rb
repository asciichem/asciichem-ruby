# frozen_string_literal: true

module AsciiChem
  module Rinchi
    # Engine that drives the native chemomer engine's reaction-identity
    # surface (the RInChI layer, chemomer 1.1.0+) through its C ABI —
    # the same transport the identity derivation uses
    # (AsciiChem::Inchi::NativeEngine): a documented external artifact,
    # nothing vendored — build the cdylib once from the chemomer
    # checkout (`cargo build --release`) and point CHEMOMER_LIB at it.
    # The `ffi` gem loads lazily — the core gem stays dependency-free.
    #
    #   AsciiChem::Rinchi.derive_from_rxnfile(rxnfile)   # CHEMOMER_LIB
    #   AsciiChem::Rinchi::NativeEngine.new(lib: "/path/libchemomer.dylib")
    #
    # The exports this engine binds (one string return each, null on
    # error with the message on chemomer_last_error, released with
    # chemomer_string_free): the RXNfile edge derives the five
    # identity lines (identifier, RAuxInfo, the three key shapes) and
    # the RDfile edge the identifier line; decode reads a RInChI (+ its
    # RAuxInfo companion) back into the component table — the flag
    # line, TAB-separated `inchi<TAB>aux<TAB>key` triples, bare `<>`
    # role separators. The forced-equilibrium reading has no C-ABI
    # entry: an RXNfile parses directional, and only the engine's own
    # model API (the rs gate) can derive under the forced flag.
    class NativeEngine
      def self.default_lib
        ENV.fetch('CHEMOMER_LIB', nil)
      end

      attr_reader :lib

      def initialize(lib: self.class.default_lib)
        super()
        @lib = lib
        unless @lib
          raise AsciiChem::Error,
                'chemomer native engine: set CHEMOMER_LIB to the built cdylib ' \
                '(cargo build --release in the chemomer checkout)'
        end
        return if File.readable?(@lib)

        raise AsciiChem::Error, "chemomer native engine: #{@lib} is not readable"
      end

      # RXNfile → the five identity lines (engine-verbatim — the key
      # headers included), mirroring asciichem::rinchi's RinchiRecord.
      def derive_from_rxnfile(rxnfile)
        Record.new(
          rinchi: call(rxnfile, :chemomer_rinchi_from_rxn),
          rauxinfo: call(rxnfile, :chemomer_rinchi_aux_from_rxn),
          rinchikey: call(rxnfile, :chemomer_rinchi_short_key_from_rxn),
          long_key: call(rxnfile, :chemomer_rinchi_long_key_from_rxn),
          web_key: call(rxnfile, :chemomer_rinchi_web_key_from_rxn)
        )
      end

      # RDfile → the identifier line. The C ABI exports the identifier
      # only for this edge (the other four lines ride the RXN exports'
      # assembly under the engine's own gate), so the remaining fields
      # stay nil — the record carries what the transport provides.
      def derive_from_rdfile(rdfile)
        Record.new(rinchi: call(rdfile, :chemomer_rinchi_from_rd))
      end

      # RInChI (+ RAuxInfo companion; pass "" when unknown) → the
      # decoded reaction: the components carry their identities (and
      # aux/key content) straight from the strings, the direction flag
      # recovers the real roles, and no structures are rebuilt.
      def decode(rinchi, rauxinfo: '')
        table = call(rinchi, :chemomer_rinchi_decode, rauxinfo)
        decode_component_table(table)
      end

      # The C ABI surface this engine binds — one string in, one string
      # out (null on error, released with chemomer_string_free), decode
      # taking the RInChI and its RAuxInfo companion. Listed once so the
      # binding module attaches them in one walk.
      EXPORTS = [
        [:chemomer_rinchi_from_rxn, %i[string]],
        [:chemomer_rinchi_aux_from_rxn, %i[string]],
        [:chemomer_rinchi_short_key_from_rxn, %i[string]],
        [:chemomer_rinchi_long_key_from_rxn, %i[string]],
        [:chemomer_rinchi_web_key_from_rxn, %i[string]],
        [:chemomer_rinchi_from_rd, %i[string]],
        [:chemomer_rinchi_decode, %i[string string]],
        [:chemomer_string_free, %i[pointer], :void],
        [:chemomer_last_error, [], :pointer]
      ].freeze

      # One FFI module per library path, cached: attach_function
      # defines the symbol bindings once.
      def self.binding_class(path)
        @binding_classes ||= {}
        @binding_classes[path] ||= begin
          require 'ffi'
          Module.new do
            extend FFI::Library

            ffi_lib path
            EXPORTS.each { |name, args, ret = :pointer| attach_function name, args, ret }

            def self.last_error
              pointer = chemomer_last_error
              pointer.null? ? nil : pointer.read_string
            end
          end
        end
      end

      private

      def call(input, function, second = nil)
        binding_class = self.class.binding_class(@lib)
        pointer = if second.nil?
                    binding_class.public_send(function, input)
                  else
                    binding_class.public_send(function, input, second)
                  end
        # An FFI null return is a TRUTHY pointer object — `unless pointer`
        # never fires; nil?/null? is the only correct emptiness test.
        if pointer.nil? || pointer.null?
          message = binding_class.last_error
          raise AsciiChem::Error, "chemomer native engine: #{message || 'call failed'}"
        end
        value = pointer.read_string
        binding_class.chemomer_string_free(pointer)
        value
      end

      # The component table's wire form (documented on the engine's
      # RinchiReaction::component_table): the first line is the
      # direction flag, the bare `<>` lines separate the three roles,
      # and every other line is one component's TAB-separated identity
      # triple. The strings carry no tab and no newline, so the table
      # splits unambiguously.
      def decode_component_table(table)
        lines = table.split("\n")
        directionality = decode_directionality(lines.shift)
        roles = decode_roles(lines)
        Reaction.new(
          directionality: directionality,
          reactants: roles[:reactants],
          products: roles[:products],
          agents: roles[:agents]
        )
      end

      # The flag line: `=` speaks equilibrium; `+` (and the engine's
      # never-emitted `-`, whose roles arrive pre-resolved) directional.
      def decode_directionality(flag)
        flag == '=' ? :equilibrium : :directional
      end

      # Walks the component lines into the three roles, the bare `<>`
      # separators advancing the role cursor.
      def decode_roles(lines)
        roles = { reactants: [], products: [], agents: [] }
        role_order = %i[reactants products agents]
        role = 0
        lines.each do |line|
          if line == '<>'
            role += 1
          else
            roles[role_order[role]] << decode_component(line)
          end
        end
        roles
      end

      # One line's identity triple (InChI, AuxInfo, InChIKey).
      def decode_component(line)
        inchi, aux, inchikey = line.split("\t")
        Component.new(inchi: inchi.to_s, aux: aux.to_s, inchikey: inchikey.to_s)
      end
    end
  end
end
