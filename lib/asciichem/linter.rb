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
    autoload :BalanceCheck, "asciichem/linter/balance_check"
    autoload :BracketBalanceCheck, "asciichem/linter/bracket_balance_check"
    autoload :ElementValidationCheck, "asciichem/linter/element_validation_check"
    autoload :Diagnostic, "asciichem/linter/diagnostic"
    autoload :IsotopeSanityCheck, "asciichem/linter/isotope_sanity_check"
    autoload :Registry, "asciichem/linter/registry"
    autoload :UnclosedRingCheck, "asciichem/linter/unclosed_ring_check"
    autoload :ValenceCheck, "asciichem/linter/valence_check"

    SEVERITIES = %i[error warning info].freeze

    # Run all registered checks against the model. Returns an array of
    # Diagnostic objects (empty if no issues).
    def self.run(formula)
      Registry.all.flat_map { |check| check.new.run(formula) }
    end

    # Convenience: returns true if any check produced an error.
    def self.errors?(formula)
      run(formula).any? { |d| d.severity == :error }
    end

    # Eagerly trigger every autoload in this module so check files can
    # self-register. Runs once at module-load time.
    constants.each { |name| const_get(name) }
  end
end
