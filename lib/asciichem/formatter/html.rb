# frozen_string_literal: true

module AsciiChem
  module Formatter
    # Renders a Model tree as inline HTML using `<sub>` and `<sup>` tags.
    # Suitable for inline display in pages that don't want to load
    # MathJax or render MathML.
    #
    # Example: `H_2O` -> <code>H<sub>2</sub>O</code>.
    class Html < Base
      def visit_formula(formula)
        formula.nodes.map { |n| render_node(n) }.join
      end

      def visit_molecule(molecule)
        prefix = molecule.coefficient.nil? || molecule.coefficient.to_s.empty? ? "" : "#{escape(molecule.coefficient)}"
        body = molecule.nodes.map { |n| render_node(n) }.join
        "#{prefix}#{body}"
      end

      def visit_atom(atom)
        parts = []
        parts << "<sup>#{escape(atom.isotope)}</sup>" if atom.isotope
        parts << escape(atom.element)
        parts << "<sub>#{escape(atom.subscript)}</sub>" if atom.subscript
        parts << "<sup>#{escape(atom.superscript)}</sup>" if atom.superscript
        parts << "<sup>#{escape(atom.charge)}</sup>" if atom.charge
        if atom.oxidation_state
          parts << "<sup>(#{escape(atom.oxidation_state)})</sup>"
        end
        parts.join
      end

      def visit_group(group)
        body = group.nodes.map { |n| render_node(n) }.join
        suffix = group.multiplicity ? "<sub>#{escape(group.multiplicity)}</sub>" : ""
        "#{escape(group.open_char)}#{body}#{escape(group.close_char)}#{suffix}"
      end

      def visit_bond(bond)
        escape(bond.ascii)
      end

      def visit_reaction(reaction)
        left = reaction.reactants.map { |n| render_node(n) }.join(" + ")
        right = reaction.products.map { |n| render_node(n) }.join(" + ")
        arrow = escape(reaction.arrow_entity)
        conds = reaction.conditions
        return "#{left} #{arrow} #{right}" unless conds

        above = conds.above ? "<sup>#{escape(conds.above)}</sup>" : ""
        below = conds.below ? "<sub>#{escape(conds.below)}</sub>" : ""
        "#{left} #{above}#{arrow}#{below} #{right}"
      end

      def visit_reaction_cascade(cascade)
        return "" if cascade.steps.empty?

        head = cascade.steps.first
        out = head.reactants.map { |n| render_node(n) }.join(" + ")
        cascade.steps.each do |step|
          arrow = escape(step.arrow_entity)
          conds = step.conditions
          if conds
            above = conds.above ? "<sup>#{escape(conds.above)}</sup>" : ""
            below = conds.below ? "<sub>#{escape(conds.below)}</sub>" : ""
            out += " #{above}#{arrow}#{below}"
          else
            out += " #{arrow}"
          end
          out += " " + step.products.map { |n| render_node(n) }.join(" + ")
        end
        out
      end

      def visit_electron_configuration(ec)
        ec.orbitals.map { |orb, occ| "#{escape(orb)}<sup>#{escape(occ)}</sup>" }.join(" ")
      end

      def visit_embedded_math(em)
        em.formula.to_mathml
      end

      def visit_text(text)
        escape(text.content)
      end

      private

      def render_node(node)
        node.accept(self)
      end

      # Minimal HTML escaper. The model content is plain text (digits,
      # element symbols, conditions text) so we only need the four
      # XML-mandated characters.
      def escape(string)
        return "" if string.nil?

        string.to_s
              .gsub("&", "&amp;")
              .gsub("<", "&lt;")
              .gsub(">", "&gt;")
              .gsub('"', "&quot;")
      end
    end
  end
end
