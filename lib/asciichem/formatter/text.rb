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
        formula.nodes.map { |n| render_node(n) }.join(" ")
      end

      def visit_molecule(molecule)
        prefix = molecule.coefficient.nil? || molecule.coefficient.empty? ? "" : molecule.coefficient.to_s
        stereo = molecule.stereo ? "(#{molecule.stereo_letter})-" : ""
        body = molecule.nodes.map { |n| render_node(n) }.join
        annotations = molecule_annotations(molecule)
        "#{stereo}#{prefix}#{body}#{annotations}"
      end

      def molecule_annotations(molecule)
        parts = []
        molecule.names.each { |n| parts << %(@name("#{n.content}")) }
        molecule.identifiers.each { |i| parts << %(@#{i.convention}("#{i.value}")) }
        parts << %(@title("#{molecule.title}")) if molecule.title
        molecule.formulas.each { |f| parts << %(@formula("#{f[:concise]}")) if f[:concise] }
        molecule.labels.each { |l| parts << %(@label("#{l[:value]}")) if l[:value] }
        molecule.properties.each { |p| parts << %(@#{p[:title]}("#{p[:value]}")) if p[:title] && p[:value] }
        molecule.metadata.each { |m| parts << %(@meta("#{m[:name]}","#{m[:content]}")) }
        parts.empty? ? "" : " #{parts.join}"
      end

      def visit_atom(atom)
        parts = []
        parts << (":" * atom.lone_pairs) if atom.lone_pairs
        parts << "^#{atom.isotope}"        if atom.isotope
        parts << atom.element
        parts << "_#{atom.subscript}"      if atom.subscript
        parts << "^#{atom.superscript}"    if atom.superscript
        parts << "^#{atom.charge}"         if atom.charge
        parts << "^(#{atom.oxidation_state})" if atom.oxidation_state
        parts << ("." * atom.radical_electrons) if atom.radical_electrons
        parts << atom.ring_closures.to_s if atom.ring_closures
        parts << atom_annotation(atom)
        parts.join
      end

      def atom_annotation(atom)
        parts = []
        if atom.x2 && atom.y2
          coord = "@(#{format_coord(atom.x2)},#{format_coord(atom.y2)}"
          coord << ",#{format_coord(atom.z2)}" if atom.z2
          parts << "#{coord})"
        end
        parts << "@#{atom.atom_parity}" if atom.atom_parity
        parts << "@m(#{atom.spin_multiplicity})" if atom.spin_multiplicity
        parts << %(@t("#{atom.atom_title}")) if atom.atom_title
        if atom.x_fract && atom.y_fract && atom.z_fract
          parts << "@f(#{format_coord(atom.x_fract)},#{format_coord(atom.y_fract)},#{format_coord(atom.z_fract)})"
        end
        parts.join
      end

      def format_coord(value)
        value == value.to_i ? value.to_i.to_s : value.to_s
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

      def visit_reaction_cascade(cascade)
        return "" if cascade.steps.empty?

        head = cascade.steps.first
        out = "#{render_terms(head.reactants)} #{render_arrow_with_conditions(head)} #{render_terms(head.products)}"
        cascade.steps.drop(1).each do |step|
          out += " #{render_arrow_with_conditions(step)} #{render_terms(step.products)}"
        end
        out
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
        %("#{text.content}")
      end

      def visit_crystal(crystal)
        parts = ["crystal"]
        parts << "[#{crystal.name}]" if crystal.name
        params = []
        params << "a=#{crystal.a}" if crystal.a
        params << "b=#{crystal.b}" if crystal.b
        params << "c=#{crystal.c}" if crystal.c
        params << "alpha=#{crystal.alpha}" if crystal.alpha
        params << "beta=#{crystal.beta}" if crystal.beta
        params << "gamma=#{crystal.gamma}" if crystal.gamma
        params << "sg=#{crystal.spacegroup}" if crystal.spacegroup
        parts << "(#{params.join(',')})" unless params.empty?
        atom_strs = crystal.atoms.map { |a| render_node(a) }
        parts << "{#{atom_strs.join(' ')}}" unless atom_strs.empty?
        parts.join
      end

      private

      def render_node(node)
        node.accept(self)
      end

      def render_terms(terms)
        terms.map { |n| render_node(n) }.join(" + ")
      end

      def render_arrow_with_conditions(reaction)
        arrow = reaction.arrow_ascii
        conds = reaction.conditions
        return arrow unless conds

        above = conds.above ? "[#{conds.above}]" : ""
        below = conds.below ? "[#{conds.below}]" : ""
        "#{arrow}#{above}#{below}"
      end
    end
  end
end
