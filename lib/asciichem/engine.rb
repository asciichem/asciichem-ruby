# frozen_string_literal: true

module AsciiChem
  # Parsing engine selector (TODO.impl 63/64; parsanol-ruby#25).
  #
  # The reference engine is :parslet (pure Ruby, zero extra
  # dependencies) and remains the default. The :parsanol engine runs
  # the SAME rules (GrammarRules/TransformRules) over Parsanol's
  # Rust-backed parslet-compat layer — the shared corpus passes
  # byte-for-byte (221/221) at ~3x parslet speed.
  #
  # Parsanol is an opt-in soft dependency; the gemspec is unchanged:
  #
  #   # Gemfile
  #   gem "parsanol", "~> 1.3.16"
  #
  #   require "asciichem/engine/parsanol_engine"
  #   AsciiChem::Engine.use(:parsanol)
  #   AsciiChem.parse("H_2O")   # parsed by the Rust core
  #
  # The active engine may also be selected via ASCIICHEM_ENGINE
  # (a testing seam, mirroring ASCIICHEM_CORPUS):
  #
  #   ASCIICHEM_ENGINE=parsanol bundle exec rspec
  #
  module Engine
    class Error < AsciiChem::Error; end

    # The named engine exists but its gem is not installed.
    class NotAvailableError < Error; end

    autoload :ParsletEngine, 'asciichem/engine/parslet_engine'
    autoload :ParsanolEngine, 'asciichem/engine/parsanol_engine'

    class << self
      # Selects the engine by name. Returns the engine class.
      def use(name)
        @current = engine_for(name)
      end

      # The active engine. Defaults to :parslet, overridable once via
      # ASCIICHEM_ENGINE at first use.
      def current
        @current ||= engine_for(ENV.fetch('ASCIICHEM_ENGINE', 'parslet'))
      end

      private

      def engine_for(name)
        case name.to_s
        when 'parslet' then ParsletEngine
        when 'parsanol' then ParsanolEngine
        else
          raise Error, "unknown engine #{name.inspect} (available: parslet, parsanol)"
        end
      end
    end
  end
end
