# frozen_string_literal: true

require 'open3'

module AsciiChem
  module Inchi
    # Engine that shells out to the standalone IUPAC `inchi-1`
    # binary. The binary is a documented external dependency — nothing
    # is vendored (vendoring the InChI library requires the licence
    # review recorded in TODO.v2 10, a maintainer decision).
    #
    #   AsciiChem::Inchi.engine = AsciiChem::Inchi::BinaryEngine.new
    #   AsciiChem::Inchi.engine = AsciiChem::Inchi::BinaryEngine.new(bin: "/usr/local/bin/inchi-1")
    class BinaryEngine < Engine
      DEFAULT_FLAGS = %w[-STDIO -AuxNone -NoLabels -Key].freeze

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

      def execute(input)
        out, err, status = Open3.capture3(bin, *flags, stdin_data: input)
        unless status.success?
          raise AsciiChem::Error, "#{bin} failed (exit #{status.exitstatus}): #{(err + out).strip[0, 500]}"
        end

        out
      rescue Errno::ENOENT
        raise EngineMissingError, "InChI engine binary #{bin.inspect} not found — #{AsciiChem::Inchi::INSTALL_GUIDE}"
      end
    end
  end
end
