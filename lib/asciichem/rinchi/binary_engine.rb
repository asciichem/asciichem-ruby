# frozen_string_literal: true

require 'open3'

module AsciiChem
  module Rinchi
    # Engine that shells out to the standalone IUPAC `rinchi-1`
    # binary. The binary is a documented external dependency — nothing
    # is vendored (vendoring requires the licence review recorded in
    # TODO.v2/10, a maintainer decision).
    #
    #   AsciiChem::Rinchi.engine = AsciiChem::Rinchi::BinaryEngine.new
    #   AsciiChem::Rinchi.engine = AsciiChem::Rinchi::BinaryEngine.new(bin: "/usr/local/bin/rinchi-1")
    class BinaryEngine
      DEFAULT_FLAGS = %w[-STDIO -AuxNone -NoLabels -Key].freeze

      attr_reader :bin, :flags

      def initialize(bin: 'rinchi-1', flags: DEFAULT_FLAGS)
        super()
        @bin = bin
        @flags = flags.freeze
      end

      # reaction → RXN → rinchi-1 → Identity. The RXN emission is the
      # pipe: reactants and products cross into the engine as V2000
      # mol blocks inside one $RXN container.
      def identity(reaction)
        rxn = AsciiChem::Rxn.write(reaction)
        out = execute(rxn)
        rinchi = out[/^RInChI=\S+/]
        raise AsciiChem::Error, "#{bin} produced no RInChI:\n#{out}" unless rinchi

        Identity.new(
          rinchi: rinchi,
          short_rinchikey: out[/^Short-RInChIKey=(\S+)/, 1],
          long_rinchikey: out[/^Long-RInChIKey=(\S+)/, 1]
        )
      end

      private

      def execute(input)
        out, err, status = Open3.capture3(bin, *flags, stdin_data: input)
        unless status.success?
          raise AsciiChem::Error, "#{bin} failed (exit #{status.exitstatus}): #{(err + out).strip[0, 500]}"
        end

        out
      rescue Errno::ENOENT
        raise EngineMissingError, "RInChI engine binary #{bin.inspect} not found — #{AsciiChem::Rinchi::INSTALL_GUIDE}"
      end
    end
  end
end
