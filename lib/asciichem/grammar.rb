# frozen_string_literal: true

require "parslet"

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
    root :formula

    # -- top level ---------------------------------------------------------

    rule(:formula) do
      spaces? >> nodes.as(:formula) >> spaces?
    end

    rule(:nodes) { node.repeat(1) }

    rule(:node)  { reaction | electron_config | molecule | embedded_math | text_run }

    # -- reactions ---------------------------------------------------------

    rule(:reaction) do
      terms.as(:reactants) >>
        arrow.as(:arrow) >>
        spaces? >>
        terms.as(:products)
    end

    rule(:terms) do
      molecule >> (spaces? >> plus >> spaces? >> molecule).repeat
    end

    rule(:plus) { str("+") }

    rule(:arrow) do
      spaces? >>
        arrow_token.as(:kind) >>
        condition.maybe.as(:above) >>
        condition.maybe.as(:below)
    end

    rule(:condition) do
      str("[") >> (str("]").absent? >> any).repeat.as(:text) >> str("]")
    end

    rule(:arrow_token) do
      str("<=>") | str("<->") | str("->") | str("<-")
    end

    # -- molecules ---------------------------------------------------------

    rule(:molecule) do
      coefficient.maybe >> units.as(:units)
    end

    rule(:units) { unit.repeat(1) }
    rule(:unit)  { prefixed_atom | group | plain_atom }

    rule(:coefficient) do
      (digits.as(:value) >> (element_symbol | open_bracket).present?).as(:coefficient)
    end

    rule(:open_bracket) { str("(") | str("[") | str("{") }

    # -- atoms -------------------------------------------------------------

    rule(:prefixed_atom) do
      isotope_marker.as(:isotope) >>
        element_symbol.as(:element) >>
        atom_suffix
    end

    rule(:plain_atom) do
      element_symbol.as(:element) >> atom_suffix
    end

    rule(:atom_suffix) do
      subscript_marker.maybe.as(:subscript) >>
        superscript_marker.maybe.as(:superscript)
    end

    # Markers consume the leading `_` / `^` but capture only the value.
    rule(:isotope_marker) do
      (str("^") | str("_")) >> digits
    end

    rule(:subscript_marker) do
      str("_") >> subscript_value
    end

    rule(:superscript_marker) do
      str("^") >> superscript_value
    end

    rule(:element_symbol) do
      match("[A-Z]") >> match("[a-z]").maybe
    end

    rule(:subscript_value) do
      (str("{") >> (str("}").absent? >> any).repeat >> str("}")) |
        digits
    end

    rule(:superscript_value) do
      oxidation_state | charge | braced_or_bare
    end

    rule(:charge) do
      (digits >> match("[+-]")) |
        (match("[+-]") >> digits.maybe) |
        digits
    end

    rule(:oxidation_state) do
      str("(") >> roman_numeral >> str(")")
    end

    rule(:roman_numeral) { match("[IVXLCDM]").repeat(1) }

    rule(:braced_or_bare) do
      (str("{") >> (str("}").absent? >> any).repeat >> str("}")) |
        match("[0-9a-zA-Z]").repeat(1)
    end

    # -- groups ------------------------------------------------------------

    rule(:group) do
      group_open.as(:open_bracket) >>
        group_nodes >>
        group_close.as(:close_bracket) >>
        multiplicity.maybe.as(:multiplicity)
    end

    # `group_nodes` is a separate rule so we can carve out the closing
    # bracket from `node`'s text fallback. Without this, `text_run`
    # would consume the closing bracket and the group never terminates.
    rule(:group_nodes) do
      group_node.repeat(1).as(:group_nodes)
    end

    rule(:group_node) do
      reaction | electron_config | molecule | embedded_math | group_text_run
    end

    rule(:group_text_run) do
      (str("`").absent? >>
       plus.absent? >>
       arrow_token.absent? >>
       group_open.absent? >>
       group_close.absent? >>
       any).repeat(1)
    end

    rule(:group_open)  { str("(") | str("[") | str("{") }
    rule(:group_close) { str(")") | str("]") | str("}") }

    rule(:multiplicity) { str("_") >> digits }

    # -- electron configuration -------------------------------------------

    rule(:electron_config) do
      (orbital.as(:orbital) >> str("^") >> digits.as(:occupancy)).repeat(2)
    end

    rule(:orbital) { digits >> match("[spdfgh]") }

    # -- embedded math ----------------------------------------------------

    rule(:embedded_math) do
      str("`") >>
        (str("`").absent? >> any).repeat.as(:math_source) >>
        str("`")
    end

    # -- text (top level) -------------------------------------------------

    # Excludes structural characters so group/reaction boundaries stay
    # crisp. The trade-off is that free-form text cannot contain
    # brackets or operators; chemistry rarely needs that.
    rule(:text_run) do
      (str("`").absent? >>
       plus.absent? >>
       arrow_token.absent? >>
       group_open.absent? >>
       group_close.absent? >>
       any).repeat(1)
    end

    # -- primitives -------------------------------------------------------

    rule(:digits)   { match("[0-9]").repeat(1) }
    rule(:spaces)   { match(/\s/).repeat(1) }
    rule(:spaces?)  { spaces.maybe }
  end
end
