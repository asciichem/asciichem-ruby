# frozen_string_literal: true

require 'open3'

module AsciiChem
  module Inchi
    # Engine that shells out to the standalone IUPAC `inchi-1`
    # binary. The binary is a documented external dependency — nothing
    # is vendored (TODO.v2 16 keeps it that way; the native path is a
    # separate engine).
    #
    # Contract: the distributed binary's file interface
    # (`inchi-1 input.mol output.txt [flags]`). `-STDIO` is NOT part
    # of it — the standard distribution ignores it and prints usage
    # (caught against the brew 1.07.5 build), so the engine stages the
    # molfile to a temp file and reads the output file back, the same
    # shape as the RInChI engine.
    #
    #   AsciiChem::Inchi.engine = AsciiChem::Inchi::BinaryEngine.new
    #   AsciiChem::Inchi.engine = AsciiChem::Inchi::BinaryEngine.new(bin: "/usr/local/bin/inchi-1")
    class BinaryEngine < Engine
      DEFAULT_FLAGS = %w[-AuxNone -NoLabels -Key].freeze

      attr_reader :bin, :flags

      def initialize(bin: 'inchi-1', flags: DEFAULT_FLAGS)
        super()
        @bin = bin
        @flags = flags.freeze
      end

      # model → molfile → inchi-1 → Identity. The molfile emission is
      # the pipe: atom coordinates, charges and isotopes cross into
      # the engine through the V2000 block.
      def identity(molecule)
        molfile = AsciiChem::Molfile.write(molecule)
        out = execute(molfile)
        inchi = out[/^InChI=\S+/]
        raise AsciiChem::Error, "#{bin} produced no InChI:\n#{out}" unless inchi

        inchikey = out[/^InChIKey=(\S+)/, 1]
        raise AsciiChem::Error, "#{bin} produced no InChIKey (pass -Key):\n#{out}" unless inchikey

        Identity.new(inchi: inchi, inchikey: inchikey)
      end

      private

      def execute(molfile)
        require 'tmpdir'
        Dir.mktmpdir('asciichem-inchi') do |dir|
          input = File.join(dir, 'structure.mol')
          output = File.join(dir, 'structure.txt')
          File.write(input, molfile)
          _out, err, status = Open3.capture3(bin, input, output, *flags)
          unless status.success?
            raise AsciiChem::Error, "#{bin} failed (exit #{status.exitstatus}): #{err.strip[0, 500]}"
          end

          # A clean run with no output file means no structure output;
          # the caller's InChI= regex raises the no-InChI error.
          File.exist?(output) ? File.read(output) : ''
        end
      rescue Errno::ENOENT
        raise EngineMissingError, "InChI engine binary #{bin.inspect} not found — #{AsciiChem::Inchi::INSTALL_GUIDE}"
      end
    end
  end
end
