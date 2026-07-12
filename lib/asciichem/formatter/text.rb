# frozen_string_literal: true

module AsciiChem
  module Formatter
    # Renders a Model tree as canonical AsciiChem text. Round-trip
    # conformance: `AsciiChem.parse(s).to_text == s` for any conformant
    # `s`. The formatter is the canonicaliser — equivalent inputs map
    # to the same output.
    #
    # Canonicalisation rules (v1):
    # - Explicit subscript marker: `H_2`, not `H2`.
    # - Coefficient before molecule: `2H_2O`.
    # - Isotope binds to atom: `^14C` (no `{}` carrier).
    # - Charge is number-then-sign per IUPAC: `Ca^2+`.
    # - Oxidation state in roman numerals with parens: `Fe^(III)`.
    # - Group brackets preserved from input.
    # - Reaction arrows use the canonical ASCII spelling (`->`, `<-`,
    #   `<=>`, `<->`).
    class Text < Base
      def visit_formula(formula)
        formula.nodes.map { |n| render_node(n) }.join
      end

      def visit_molecule(molecule)
        prefix = molecule.coefficient.nil? || molecule.coefficient.empty? ? "" : molecule.coefficient.to_s
        body = molecule.nodes.map { |n| render_node(n) }.join
        "#{prefix}#{body}"
      end

      def visit_atom(atom)
        parts = []
        parts << "^#{atom.isotope}"        if atom.isotope
        parts << atom.element
        parts << "_#{atom.subscript}"      if atom.subscript
        parts << "^#{atom.superscript}"    if atom.superscript
        parts << "^#{atom.charge}"         if atom.charge
        parts << "^(#{atom.oxidation_state})" if atom.oxidation_state
        parts.join
      end

      def visit_group(group)
        body = group.nodes.map { |n| render_node(n) }.join
        suffix = group.multiplicity ? "_#{group.multiplicity}" : ""
        "#{group.open_char}#{body}#{group.close_char}#{suffix}"
      end

      def visit_bond(bond)
        bond.ascii
      end

      def visit_reaction(reaction)
        left = reaction.reactants.map { |n| render_node(n) }.join(" + ")
        right = reaction.products.map { |n| render_node(n) }.join(" + ")
        arrow = reaction.arrow_ascii
        conds = reaction.conditions
        return "#{left} #{arrow} #{right}" unless conds

        above = conds.above ? "[#{conds.above}]" : ""
        below = conds.below ? "[#{conds.below}]" : ""
        "#{left} #{arrow}#{above}#{below} #{right}"
      end

      def visit_electron_configuration(ec)
        parts = ec.orbitals.map { |orb, occ| "#{orb}^#{occ}" }
        parts << ec.term_symbol.to_s if ec.term_symbol
        parts.join(" ")
      end

      def visit_embedded_math(em)
        "`#{em.source}`"
      end

      def visit_text(text)
        text.content
      end

      private

      def render_node(node)
        node.accept(self)
      end
    end
  end
end
