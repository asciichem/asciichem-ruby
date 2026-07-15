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

    rule(:nodes) { node >> (spaces? >> node).repeat }

    rule(:node)  { reaction_cascade | reaction | electron_config | annotated_molecule | molecule | embedded_math | text_run.as(:text_run) }

    # Annotated molecule: a molecule followed by one or more
    # `@key("value")` annotations for CML metadata (names,
    # identifiers, title, formula, labels).
    rule(:annotated_molecule) do
      molecule.as(:mol) >> molecule_annotation.repeat(1).as(:annotations)
    end

    rule(:molecule_annotation) do
      spaces?.maybe >>
      (metadata_annotation | simple_annotation)
    end

    # Metadata: @meta("key","value") — two quoted args, comma-separated.
    # Produces CML <metadata name="key" content="value"/>.
    # Uses distinct capture keys (meta_key/meta_value) so the transform
    # can distinguish metadata from regular @key("value") annotations.
    rule(:metadata_annotation) do
      str('@meta(') >> str('"') >>
      (str('"').absent? >> any).repeat.as(:meta_key) >> str('"') >>
      str(',') >> str('"') >>
      (str('"').absent? >> any).repeat.as(:meta_value) >> str('"') >>
      str(')')
    end

    # Simple annotation: @key("value") — one quoted arg.
    # Known types (name, inchi, etc.) are handled specially by the
    # transform. Unknown types become properties.
    rule(:simple_annotation) do
      str('@') >> annotation_type.as(:ann_type) >>
      str('(') >> str('"') >>
      (str('"').absent? >> any).repeat.as(:ann_value) >>
      str('"') >> str(')')
    end

    # Known annotation types first; property_name is a catch-all so
    # any lowercase word (e.g. "mw", "density", "logP") becomes a
    # property annotation.
    rule(:annotation_type) do
      str('name') | str('title') | str('formula') | str('label') |
      str('inchi') | str('smiles') | str('cas') | str('iupac') |
      str('cid') | str('chebi') |
      property_name
    end

    rule(:property_name) do
      match('[a-z]').repeat(1)
    end

    # -- reactions ---------------------------------------------------------

    # A reaction cascade is two or more reactions chained together:
    # the products of step N become the reactants of step N+1, with
    # an arrow between them. The grammar reuses `reaction` for the
    # first leg and `arrow >> terms` for each subsequent leg; the
    # transform promotes the whole chain to a `ReactionCascade`.
    rule(:reaction_cascade) do
      (reaction.as(:first) >>
        (arrow.as(:arrow) >> spaces? >> terms.as(:products)).repeat(1)).as(:cascade)
    end

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
      stereo_prefix.maybe >> coefficient.maybe >> units.as(:units)
    end

    # Stereochemistry prefix: `(R)-`, `(S)-`, `(E)-`, `(Z)-`,
    # `(a)-`/`(α)-` (alpha), `(b)-`/`(β)-` (beta). Tried before
    # `coefficient` so the lookahead-via-failure on the closed letter
    # set disambiguates from a parenthesised group: `(R)` matches
    # because `R` is in the stereo set; `(OH)` fails because `OH` is
    # not a single stereo letter, and the molecule rule falls through
    # to the regular group parse.
    rule(:stereo_prefix) do
      str("(") >> stereo_letter.as(:stereo) >> str(")") >> str("-")
    end

    rule(:stereo_letter) do
      str("alpha") | str("beta") |
        str("R") | str("S") | str("E") | str("Z") |
        str("α") | str("β") |
        str("a") | str("b")
    end

    rule(:units) { (unit | bond).repeat(1) }
    rule(:unit)  { prefixed_atom | group | plain_atom }

    # Bonds appear inside molecules as separators between units.
    # Supported kinds, in alternation order (longest match first to
    # avoid `>-` shadowing `-`):
    #   single    `-`
    #   double    `=`
    #   triple    `#`
    #   quadruple `##`
    #   wedge     `>-`  (solid wedge toward viewer)
    #   hash      `-<`  (hashed wedge away from viewer)
    #   dative    `~>`  (electron-pair donor → acceptor; `->` is taken
    #                    by the reaction arrow)
    #   wavy      `~~`  (resonance / delocalised)
    rule(:bond) do
      str("##").as(:quadruple) |
        str(">-").as(:wedge) |
        str("-<").as(:hash) |
        str("~>").as(:dative) |
        str("~~").as(:wavy) |
        str("#").as(:triple) |
        str("=").as(:double) |
        str("-").as(:single)
    end

    rule(:coefficient) do
      (digits.as(:value) >> (element_symbol | open_bracket).present?).as(:coefficient)
    end

    rule(:open_bracket) { str("(") | str("[") | str("{") }

    # -- atoms -------------------------------------------------------------

    rule(:prefixed_atom) do
      (lewis_prefix.maybe >>
        isotope_marker.as(:isotope) >>
        element_symbol.as(:element) >>
        atom_suffix >>
        lewis_radicals.maybe >>
        ring_closures.maybe.as(:ring_closures) >>
        atom_annotation.maybe).as(:atom)
    end

    rule(:plain_atom) do
      (lewis_prefix.maybe >>
        element_symbol.as(:element) >>
        atom_suffix >>
        lewis_radicals.maybe >>
        ring_closures.maybe.as(:ring_closures) >>
        atom_annotation.maybe).as(:atom)
    end

    # Atom annotations: stereo parity (@R / @S) or 2D/3D coordinates
    # (@(x,y) / @(x,y,z)). Both use the `@` prefix. An atom can carry
    # at most one annotation in the grammar; multiple annotations
    # would require compound syntax (deferred).
    rule(:atom_annotation) do
      coordinate_annotation | parity_annotation
    end

    rule(:parity_annotation) do
      str('@') >> (str('R') | str('S')).as(:atom_parity)
    end

    rule(:coordinate_annotation) do
      str('@(') >>
        float_number.as(:x2) >> str(',') >>
        float_number.as(:y2) >>
        (str(',') >> float_number.as(:z2)).maybe >>
        str(')')
    end

    rule(:float_number) do
      str('-').maybe >> match('[0-9]').repeat(1) >> (str('.') >> match('[0-9]').repeat(0)).maybe
    end

    # Ring closure digits (SMILES-style). A digit suffix on an atom
    # opens or closes a ring; two atoms with the same digit become
    # bonded. Captured as a string (e.g. "1", "12") so multiple
    # closures on one atom are preserved.
    rule(:ring_closures) do
      match('[0-9]').repeat(1)
    end

    rule(:atom_suffix) do
      subscript_marker.maybe.as(:subscript) >>
        superscript_marker.maybe.as(:superscript)
    end

    # Lewis markers. Prefix `:` count = lone_pairs (binds to following
    # atom, like the isotope prefix). Suffix `.` count = radical
    # electrons. Position-specific lone pairs (`:O:` style) collapse
    # into a total count — the renderer decides layout.
    rule(:lewis_prefix) { str(":").repeat(1).as(:lone_pairs) }
    rule(:lewis_radicals) { str(".").repeat(1).as(:radical_electrons) }

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
      str('"') >> (str('"').absent? >> any).repeat >> str('"')
    end

    rule(:group_open)  { str("(") | str("[") | str("{") }
    rule(:group_close) { str(")") | str("]") | str("}") }

    rule(:multiplicity) { str("_") >> digits }

    # -- electron configuration -------------------------------------------

    rule(:electron_config) do
      (orbital.as(:orbital) >> str("^") >> digits.as(:occupancy) >> spaces?.maybe).repeat(2).as(:electron_config)
    end

    rule(:orbital) { digits >> match("[spdfgh]") }

    # -- embedded math ----------------------------------------------------

    rule(:embedded_math) do
      str("`") >>
        (str("`").absent? >> any).repeat.as(:math_source) >>
        str("`")
    end

    # -- text (top level) -------------------------------------------------

    # Free-form text uses `"..."` delimiters, matching AsciiMath's
    # convention. The quoted content becomes a Text node with the
    # surrounding quotes stripped (handled by the transform).
    rule(:text_run) do
      str('"') >> (str('"').absent? >> any).repeat >> str('"')
    end

    # -- primitives -------------------------------------------------------

    rule(:digits)   { match("[0-9]").repeat(1) }
    rule(:spaces)   { match(/\s/).repeat(1) }
    rule(:spaces?)  { spaces.maybe }
  end
end
