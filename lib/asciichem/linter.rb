# frozen_string_literal: true

module AsciiChem
  # Linter framework. The parser is total — it accepts any syntactically
  # valid input without judging chemistry correctness. The linter is a
  # separate opt-in pass that walks the model and reports chemistry
  # errors (unbalanced reactions, valence violations, etc.).
  #
  # Checks register themselves via `Linter.register(:name, Klass)`. The
  # registry is open for extension; adding a new check is a single new
  # file plus one autoload entry.
  module Linter
    autoload :Base, "asciichem/linter/base"
    autoload :BracketBalanceCheck, "asciichem/linter/bracket_balance_check"
    autoload :Diagnostic, "asciichem/linter/diagnostic"
    autoload :IsotopeSanityCheck, "asciichem/linter/isotope_sanity_check"
    autoload :Registry, "asciichem/linter/registry"

    SEVERITIES = %i[error warning info].freeze

    # Run all registered checks against the model. Returns an array of
    # Diagnostic objects (empty if no issues).
    #
    # Each check self-registers when its file loads. Autoloads are
    # triggered by iterating `constants` so every autoloaded check
    # file has a chance to register before we read the registry.
    def self.run(formula)
      constants.each { |name| const_get(name) }
      Registry.all.flat_map { |check| check.new.run(formula) }
    end

    # Convenience: returns true if any check produced an error.
    def self.errors?(formula)
      run(formula).any? { |d| d.severity == :error }
    end
  end
end
