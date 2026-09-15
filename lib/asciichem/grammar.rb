# frozen_string_literal: true

require 'parslet'

module AsciiChem
  # Parslet grammar for AsciiChem v1.
  #
  # Design notes:
  #
  # - Leaf rules return strings; `.as(:name)` is applied at the
  #   combination site so the parse tree is a flat hash of named strings
  #   wherever practical.
  # - The prefix-isotope binding (`^14C`) is enforced structurally: the
  #   `prefixed_atom` production consumes `^digits element` as a unit.
  #   A bare `^digits` without an element is rejected.
  # - Marker rules (`subscript_marker`, `superscript_marker`) capture
  #   ONLY the value, not the leading `_` or `^`. The literal prefix is
  #   consumed by the rule but not included in the named capture.
  class Grammar < Parslet::Parser
    include GrammarRules
  end
end
