# frozen_string_literal: true

module AsciiChem
  # Parsing engine selector (TODO.impl 63/64; parsanol-ruby#25).
  #
  # The directive (TODO.v2/17 slice 9; the maintainer's PARG-language
  # call): :parsanol is the DEFAULT — the SAME rules
  # (GrammarRules/TransformRules) over Parsanol's Rust-backed
  # parslet-compat layer, the shared corpus byte-for-byte at ~3x
  # parslet speed. :parslet remains as the opt-out pure-Ruby fallback
  # (ASCIICHEM_ENGINE=parslet); :parg runs the checksummed PARG
  # artifact directly.
  #
  # When the parsanol gem is unavailable, the engine falls back to
  # :parslet with a one-time warning — installs never break.
  #
  module Engine
    class Error < AsciiChem::Error; end

    # The named engine exists but its gem is not installed.
    class NotAvailableError < Error; end

    autoload :ParsletEngine, 'asciichem/engine/parslet_engine'
    autoload :ParsanolEngine, 'asciichem/engine/parsanol_engine'
    autoload :PargEngine, 'asciichem/engine/parg_engine'

    class << self
      # Selects the engine by name. Returns the engine class.
      def use(name)
        @current = engine_for(name)
      end

      # The active engine. Defaults to :parsanol (the PARG-language
      # directive), overridable once via ASCIICHEM_ENGINE
      # (e.g. ASCIICHEM_ENGINE=parslet) at first use.
      def current
        @current ||=
          begin
            engine_for(ENV.fetch('ASCIICHEM_ENGINE', 'parsanol'))
          rescue NotAvailableError
            warn 'asciichem: the parsanol gem is unavailable — ' \
                 'falling back to the parslet engine'
            engine_for('parslet')
          end
      end

      private

      def engine_for(name)
        case name.to_s
        when 'parslet' then ParsletEngine
        when 'parsanol' then ParsanolEngine
        when 'parg' then PargEngine
        else
          raise Error, "unknown engine #{name.inspect} (available: parslet, parsanol, parg)"
        end
      end
    end
  end
end
