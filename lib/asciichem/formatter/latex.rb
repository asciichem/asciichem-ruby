# frozen_string_literal: true

module AsciiChem
  module Formatter
    # Renders a Model tree as LaTeX, wrapped in `mhchem`'s `\ce{...}` at
    # the formula level only. Output requires `mhchem` in the LaTeX
    # preamble:
    #
    #   \\usepackage[version=4]{mhchem}
    #
    # Example: `H_2O` -> `\ce{H2O}`.
    class Latex < Base
      def initialize
        @inside_ce = false
      end

      def visit_formula(formula)
        within_ce { "\\ce{" + formula.nodes.map { |n| render_node(n) }.join + "}" }
      end

      def visit_molecule(molecule)
        prefix = blank?(molecule.coefficient) ? "" : molecule.coefficient.to_s
        stereo = molecule.stereo ? "(#{molecule.stereo_letter})-" : ""
        body = molecule.nodes.map { |n| render_node(n) }.join
        if @inside_ce
          "#{stereo}#{prefix}#{body}"
        else
          "\\ce{#{stereo}#{prefix}#{body}}"
        end
      end

      def visit_atom(atom)
        parts = []
        parts << "^#{wrap(atom.isotope)}" if atom.isotope
        parts << wrap(atom.element)
        parts << mhchem_subscript(atom.subscript) if atom.subscript
        if atom.charge
          parts << "^#{wrap(atom.charge)}"
        elsif atom.oxidation_state
          parts << "^{(#{wrap(atom.oxidation_state)})}"
        elsif atom.superscript
          parts << "^#{wrap(atom.superscript)}"
        end
        parts.join
      end

      def visit_group(group)
        body = group.nodes.map { |n| render_node(n) }.join
        open, close = bracket_chars(group.bracket)
        suffix = group.multiplicity ? mhchem_subscript(group.multiplicity) : ""
        "#{open}#{body}#{close}#{suffix}"
      end

      def visit_bond(bond)
        case bond.kind
        when :single then "-"
        when :double then "="
        when :triple then "\\\\equiv{}"
        else bond.ascii
        end
      end

      def visit_reaction(reaction)
        left = reaction.reactants.map { |n| render_node(n) }.join(" + ")
        right = reaction.products.map { |n| render_node(n) }.join(" + ")
        arrow = arrow_for(reaction.arrow)
        conds = reaction.conditions
        return "#{left} #{arrow} #{right}" unless conds

        above = conditions_bracket(conds.above)
        below = conditions_bracket(conds.below)
        "#{left} #{arrow}#{above}#{below} #{right}"
      end

      def visit_reaction_cascade(cascade)
        return "" if cascade.steps.empty?

        head = cascade.steps.first
        out = head.reactants.map { |n| render_node(n) }.join(" + ")
        cascade.steps.each do |step|
          arrow = arrow_for(step.arrow)
          conds = step.conditions
          if conds
            above = conditions_bracket(conds.above)
            below = conditions_bracket(conds.below)
            out += " #{arrow}#{above}#{below}"
          else
            out += " #{arrow}"
          end
          out += " " + step.products.map { |n| render_node(n) }.join(" + ")
        end
        out
      end

      def visit_electron_configuration(ec)
        inner = ec.orbitals.map { |orb, occ| "#{wrap(orb)}^#{wrap(occ)}" }.join(" ")
        "\\ce{#{inner}}"
      end

      def visit_embedded_math(em)
        "$#{em.formula.to_latex}$"
      end

      def visit_text(text)
        text.content
      end

      private

      def render_node(node)
        node.accept(self)
      end

      def within_ce
        prev = @inside_ce
        @inside_ce = true
        yield
      ensure
        @inside_ce = prev
      end

      # mhchem accepts bare digits after an element as subscripts. Use
      # bare form for digit-only values; brace form for anything else.
      def mhchem_subscript(value)
        s = value.to_s
        return s if s.match?(/\A\d+\z/)

        "_{#{s}}"
      end

      # mhchem accepts bare digits for multi-digit values (`^14`, `_12`).
      # Use braces only for non-digit values to keep output idiomatic.
      def wrap(value)
        s = value.to_s
        return s if s.match?(/\A[a-zA-Z0-9]+\z/)

        "{#{s}}"
      end

      def blank?(value)
        value.nil? || value.to_s.empty?
      end

      def bracket_chars(kind)
        case kind
        when :paren  then ["(", ")"]
        when :square then ["[", "]"]
        when :brace  then ["{", "}"]
        else ["(", ")"]
        end
      end

      def arrow_for(kind)
        case kind
        when :forward     then "->"
        when :reverse     then "<-"
        when :equilibrium then "<=>"
        when :resonance   then "<->"
        else "->"
        end
      end

      def conditions_bracket(value)
        return "" if value.nil? || value.to_s.empty?

        "[#{value}]"
      end
    end
  end
end
