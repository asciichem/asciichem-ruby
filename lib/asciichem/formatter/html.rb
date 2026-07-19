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
        inner = formula.nodes.map { |n| render_node(n) }.join
        "<span class=\"asciichem\">#{inner}</span>"
      end

      def visit_molecule(molecule)
        prefix = molecule.coefficient.nil? || molecule.coefficient.to_s.empty? ? "" : "#{escape(molecule.coefficient)}"
        stereo = molecule.stereo ? "(#{escape(molecule.stereo_letter)})-" : ""
        body = molecule.nodes.map { |n| render_node(n) }.join
        "#{stereo}#{prefix}#{body}"
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
        parts << escape(atom.ring_closures) if atom.ring_closures
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

      # -- Beyond-formulas constructs --------------------------------
      #
      # Each renders as a semantic <span class="asciichem-<kind>"> with
      # nested <dl> for key/value pairs and <ol> for ordered lists.
      # Class hooks let downstream CSS style per-construct.

      def visit_crystal(crystal)
        parts = [%(<span class="asciichem-crystal">)]
        parts << %(<span class="asciichem-name">[#{escape(crystal.name)}]</span>) if crystal.name
        parts << cell_param_dl(crystal)
        unless crystal.atoms.empty?
          parts << '<ol class="asciichem-atoms">'
          crystal.atoms.each { |a| parts << "<li>#{render_node(a)}</li>" }
          parts << '</ol>'
        end
        parts << '</span>'
        parts.join
      end

      def visit_spectrum(spectrum)
        parts = [%(<span class="asciichem-spectrum">)]
        parts << %(<span class="asciichem-type">[#{escape(spectrum.type)}]</span>) if spectrum.type
        parts << kv_dl(spectrum.params) unless spectrum.params.empty?
        unless spectrum.peaks.empty?
          parts << '<table class="asciichem-peaks">'
          parts << '<thead><tr><th>position</th><th>intensity</th><th>multiplicity</th><th>assignment</th></tr></thead>'
          parts << '<tbody>'
          spectrum.peaks.each do |peak|
            parts << '<tr>'
            parts << "<td>#{escape(peak.position)}</td>"
            parts << "<td>#{escape(peak.intensity)}</td>"
            parts << "<td>#{escape(peak.multiplicity)}</td>"
            parts << "<td>#{escape(peak.assignment)}</td>"
            parts << '</tr>'
          end
          parts << '</tbody></table>'
        end
        parts << '</span>'
        parts.join
      end

      def visit_calculation(calc)
        parts = [%(<span class="asciichem-calc">)]
        if calc.method || calc.basis
          label = [calc.method, calc.basis].compact.join("/")
          parts << %(<span class="asciichem-method">[#{escape(label)}]</span>)
        end
        unless calc.properties.empty?
          parts << '<dl class="asciichem-properties">'
          calc.properties.each do |p|
            value = escape(p.value)
            value += " #{escape(p.units)}" if p.units
            parts << "<dt>#{escape(p.title)}</dt><dd>#{value}</dd>"
          end
          parts << '</dl>'
        end
        parts << '</span>'
        parts.join
      end

      def visit_z_matrix(zm)
        parts = [%(<span class="asciichem-zmatrix">)]
        return parts.join + '</span>' if zm.rows.empty?

        parts << '<table class="asciichem-rows"><tbody>'
        zm.rows.each do |row|
          cells = [row.atom]
          cells << row.ref1 << row.distance if row.ref1
          cells << row.ref2 << row.angle if row.ref2
          cells << row.ref3 << row.dihedral if row.ref3
          parts << "<tr>#{cells.map { |c| "<td>#{escape(c)}</td>" }.join}</tr>"
        end
        parts << '</tbody></table></span>'
        parts.join
      end

      def visit_mechanism(mech)
        parts = [%(<span class="asciichem-mechanism">)]
        return parts.join + '</span>' if mech.steps.empty? && mech.spectators.empty?

        parts << '<dl class="asciichem-steps">'
        mech.steps.each do |s|
          parts << "<dt>#{escape(s.label)}</dt><dd>#{escape(s.reaction)}</dd>"
        end
        mech.spectators.each do |sp|
          parts << "<dt>spectator</dt><dd>#{escape(sp)}</dd>"
        end
        parts << '</dl></span>'
        parts.join
      end

      def visit_opaque_cml(opaque)
        %(<!-- opaque: #{escape(opaque.element_name)} -->)
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

      # -- Beyond-formulas helpers -----------------------------------

      # Cell parameters as <dl>. Uses Crystal#each_cell_param for
      # single-source-of-truth labels.
      def cell_param_dl(crystal)
        pairs = []
        crystal.each_cell_param(:html) { |label, value| pairs << [label, value] }
        kv_dl(pairs)
      end

      # Generic key-value pairs as <dl>.
      def kv_dl(pairs)
        return "" if pairs.nil? || pairs.empty?

        parts = ['<dl>']
        pairs.each do |key, value|
          parts << "<dt>#{escape(key)}</dt><dd>#{escape(value)}</dd>"
        end
        parts << '</dl>'
        parts.join
      end
    end
  end
end
