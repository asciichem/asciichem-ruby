# frozen_string_literal: true

module AsciiChem
  module Formatter
    # Renders a Model tree as a linear SVG. The SVG draws the formula
    # along a horizontal baseline with elements at fixed spacing.
    #
    # This is the linear fallback for environments that want a
    # self-contained vector output without MathML. True 2D structural
    # diagrams (skeletal formulae, rings, stereo wedges) require
    # `mn/elk-rb` integration — see Formatter::StructuralSvg.
    class Svg < Base
      LINE_HEIGHT = 40
      CHAR_WIDTH  = 14
      BASELINE    = 30

      def visit_formula(formula)
        nodes = formula.nodes
        rows = layout_rows(nodes)
        width = rows.map { |r| layout_width(r) }.max
        height = rows.size * LINE_HEIGHT + 10
        render_svg(width, height, rows)
      end

      def visit_molecule(molecule)
        prefix = molecule.coefficient.nil? || molecule.coefficient.to_s.empty? ? "" : molecule.coefficient.to_s
        stereo = molecule.stereo ? "(#{molecule.stereo_letter})-" : ""
        body = molecule.nodes.map { |n| render_node(n) }.join
        "#{stereo}#{prefix}#{body}"
      end

      def visit_atom(atom)
        parts = []
        parts << "^#{atom.isotope}" if atom.isotope
        parts << atom.element
        parts << "_#{atom.subscript}" if atom.subscript
        if atom.charge
          parts << "^#{atom.charge}"
        elsif atom.oxidation_state
          parts << "^(#{atom.oxidation_state})"
        elsif atom.superscript
          parts << "^#{atom.superscript}"
        end
        parts << atom.ring_closures.to_s if atom.ring_closures
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

      def visit_reaction_cascade(cascade)
        return "" if cascade.steps.empty?

        head = cascade.steps.first
        out = head.reactants.map { |n| render_node(n) }.join(" + ")
        cascade.steps.each do |step|
          arrow = step.arrow_ascii
          conds = step.conditions
          if conds
            above = conds.above ? "[#{conds.above}]" : ""
            below = conds.below ? "[#{conds.below}]" : ""
            out += " #{arrow}#{above}#{below}"
          else
            out += " #{arrow}"
          end
          out += " " + step.products.map { |n| render_node(n) }.join(" + ")
        end
        out
      end

      def visit_electron_configuration(ec)
        ec.orbitals.map { |orb, occ| "#{orb}^#{occ}" }.join(" ")
      end

      def visit_embedded_math(em)
        em.source.to_s
      end

      def visit_text(text)
        text.content
      end

      # -- Beyond-formulas constructs --------------------------------
      #
      # Svg is a linear text-in-SVG-wrapper formatter. For constructs
      # without a natural 2D representation, render the canonical text
      # form (same approach as visit_electron_configuration and
      # visit_embedded_math above). The Text formatter is the
      # canonicaliser; round-trip-safe by construction.

      def visit_crystal(crystal)
        AsciiChem::Formatter.render(:text, crystal)
      end

      def visit_spectrum(spectrum)
        AsciiChem::Formatter.render(:text, spectrum)
      end

      def visit_calculation(calc)
        AsciiChem::Formatter.render(:text, calc)
      end

      def visit_z_matrix(zm)
        AsciiChem::Formatter.render(:text, zm)
      end

      def visit_mechanism(mech)
        AsciiChem::Formatter.render(:text, mech)
      end

      def visit_opaque_cml(_opaque)
        ""
      end

      private

      def render_node(node)
        node.accept(self)
      end

      def layout_rows(nodes)
        # Linear layout: one row. Multi-row layout would require 2D
        # structural support — see Formatter::StructuralSvg.
        [nodes.map { |n| render_node(n) }.join]
      end

      def layout_width(row)
        row.length * CHAR_WIDTH + 20
      end

      def render_svg(width, height, rows)
        title = rows.join(" ").gsub(/[<>&]/, "" => "")
        lines = []
        lines << %(<?xml version="1.0" encoding="UTF-8"?>)
        lines << %(<svg xmlns="http://www.w3.org/2000/svg" width="#{width}" height="#{height}" viewBox="0 0 #{width} #{height}" role="img" aria-label="#{escape(title)}">)
        lines << %(  <title>#{escape(title)}</title>)
        lines << %(  <rect width="100%" height="100%" fill="transparent"/>)
        rows.each_with_index do |row, idx|
          y = BASELINE + (idx * LINE_HEIGHT)
          lines << %(  <text x="10" y="#{y}" font-family="serif" font-size="20" fill="currentColor">#{escape(row)}</text>)
        end
        lines << %(</svg>)
        lines.join("\n")
      end

      def escape(string)
        string.to_s
              .gsub("&", "&amp;")
              .gsub("<", "&lt;")
              .gsub(">", "&gt;")
      end
    end
  end
end
