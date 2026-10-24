# frozen_string_literal: true

module AsciiChem
  module Inchi
    # Engine that drives the native inchi-rs engine (the Rust port)
    # through its C ABI. The library is a documented external
    # artifact — nothing is vendored: build it once from the inchi-rs
    # checkout (`cargo build --release`) and point INCHI_RS_LIB at
    # the cdylib, the same opt-in shape as the BinaryEngine's
    # ASCIICHEM_INCHI_BIN. The `ffi` gem loads lazily — the core gem
    # stays dependency-free.
    #
    #   AsciiChem::Inchi.engine = AsciiChem::Inchi::NativeEngine.new
    #   AsciiChem::Inchi.engine = AsciiChem::Inchi::NativeEngine.new(lib: "/path/libinchi_rs.dylib")
    class NativeEngine < Engine
      DEFAULT_LIB = ENV.fetch('INCHI_RS_LIB', nil)

      attr_reader :lib

      def initialize(lib: DEFAULT_LIB)
        super()
        @lib = lib
        unless @lib
          raise AsciiChem::Error,
                'inchi-rs native engine: set INCHI_RS_LIB to the built cdylib ' \
                '(cargo build --release in the inchi-rs checkout)'
        end
        return if File.readable?(@lib)

        raise AsciiChem::Error, "inchi-rs native engine: #{@lib} is not readable"
      end

      # model → molfile → inchi-rs → Identity. The molfile emission is
      # the pipe, exactly as in the BinaryEngine.
      def identity(molecule)
        molfile = AsciiChem::Molfile.write(molecule, layout: false)
        inchi = call(molfile, :inchi_rs_from_molfile)
        inchikey = call(molfile, :inchi_rs_inchikey)
        Identity.new(inchi: inchi, inchikey: inchikey)
      end

      private

      def call(molfile, function)
        binding_class = self.class.binding_class(@lib)
        pointer = binding_class.public_send(function, molfile)
        unless pointer
          message = binding_class.last_error
          raise AsciiChem::Error, "inchi-rs native engine: #{message || 'call failed'}"
        end
        value = pointer.read_string
        binding_class.inchi_rs_string_free(pointer)
        value
      end

      # One FFI module per library path, cached: attach_function
      # defines the symbol bindings once.
      def self.binding_class(path)
        @binding_classes ||= {}
        @binding_classes[path] ||= begin
          require 'ffi'
          Module.new do
            extend FFI::Library

            ffi_lib path
            attach_function :inchi_rs_from_molfile, %i[string], :pointer
            attach_function :inchi_rs_inchikey, %i[string], :pointer
            attach_function :inchi_rs_string_free, %i[pointer], :void
            attach_function :inchi_rs_last_error, [], :pointer

            def self.last_error
              pointer = inchi_rs_last_error
              pointer.null? ? nil : pointer.read_string
            end
          end
        end
      end
    end
  end
end
