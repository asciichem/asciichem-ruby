# frozen_string_literal: true

require 'open3'
require 'tempfile'

module AsciiChem
  module Rinchi
    # Engine that shells out to the standalone IUPAC `rinchi-1`
    # binary. The binary is a documented external dependency — nothing
    # is vendored (vendoring requires the licence review recorded in
    # TODO.v2/10, a maintainer decision).
    #
    #   AsciiChem::Rinchi.engine = AsciiChem::Rinchi::BinaryEngine.new
    #   AsciiChem::Rinchi.engine = AsciiChem::Rinchi::BinaryEngine.new(bin: "/usr/local/bin/rinchi_cmdline")
    # The reference CLI (IUPAC-InChI/RInChI's `rinchi_cmdline`) takes a
    # FILE argument, not stdin, needs no flags, and prints RInChI=,
    # RAuxInfo=, Long-RInChIKey=, Short-RInChIKey= and Web-RInChIKey=
    # lines. The engine writes the RXN to a temp file, runs the binary
    # on it, and reads the identity lines back.
    class BinaryEngine
      DEFAULT_FLAGS = [].freeze

      attr_reader :bin, :flags

      def initialize(bin: 'rinchi_cmdline', flags: DEFAULT_FLAGS)
        super()
        @bin = bin
        @flags = flags.freeze
      end

      # reaction → RXN → rinchi binary → Identity. The RXN emission is
      # the pipe: reactants and products cross into the engine as V2000
      # mol blocks inside one $RXN container.
      def identity(reaction)
        out = execute(AsciiChem::Rxn.write(reaction))
        rinchi = out[/^RInChI=\S+/]
        raise AsciiChem::Error, "#{bin} produced no RInChI:\n#{out}" unless rinchi

        Identity.new(
          rinchi: rinchi,
          short_rinchikey: out[/^Short-RInChIKey=(\S+)/, 1],
          long_rinchikey: out[/^Long-RInChIKey=(\S+)/, 1]
        )
      end

      private

      def execute(rxn)
        out = err = nil
        status = nil
        Tempfile.create(['asciichem', '.rxn']) do |file|
          file.write(rxn)
          file.flush
          out, err, status = Open3.capture3(bin, file.path, *flags)
        end
        report_failure(status, err, out)
        out
      rescue Errno::ENOENT
        raise EngineMissingError, "RInChI engine binary #{bin.inspect} not found — #{AsciiChem::Rinchi::INSTALL_GUIDE}"
      end

      def report_failure(status, err, out)
        return if status&.success?

        raise AsciiChem::Error,
              "#{bin} failed (exit #{status&.exitstatus}): #{((err || '') + (out || '')).strip[0, 500]}"
      end
    end
  end
end
