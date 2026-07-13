# frozen_string_literal: true

require "nokogiri"
require "asciichem/layout"

module AsciiChem
  module Formatter
    # Renders a Model tree as a 2D structural SVG diagram using
    # elkrb-computed atom positions.
    #
    # For molecules without bonds (simple formulae like H_2O), the
    # formatter falls back to the linear Svg formatter.
    class StructuralSvg < Base
      ATOM_RADIUS = 14
      BOND_LENGTH = 2

      def visit_formula(formula)
        svg_parts = ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>"]

        molecule = formula.nodes.find { |n| n.is_a?(AsciiChem::Model::Molecule) }
        return visit_formula_linear(formula) unless molecule

        has_bonds = molecule.nodes.any? { |n| n.is_a?(AsciiChem::Model::Bond) }
        return visit_formula_linear(formula) unless has_bonds

        result = AsciiChem::Layout.layout(molecule)
        render_svg(result)
      end

      private

      def visit_formula_linear(formula)
        AsciiChem::Formatter::Svg.new.render(formula)
      end

      def render_svg(result)
        doc = Nokogiri::XML::Document.new
        svg = Nokogiri::XML::Element.new("svg", doc)
        svg["xmlns"] = "http://www.w3.org/2000/svg"
        svg["width"] = result.width.to_s
        svg["height"] = result.height.to_s
        svg["viewBox"] = "0 0 #{result.width} #{result.height}"

        # Draw bonds first (under atoms)
        result.bonds.each do |bond|
          from = result.atoms_by_id[bond.from_id]
          to = result.atoms_by_id[bond.to_id]
          next unless from && to

          svg.add_child(render_bond(doc, from, to, bond.kind))
        end

        # Draw atoms on top
        result.atoms.each do |atom|
          svg.add_child(render_atom(doc, atom))
        end

        doc.root = svg
        doc.to_xml
      end

      def render_atom(doc, atom)
        g = Nokogiri::XML::Element.new("g", doc)
        cx = atom.x + (ATOM_RADIUS * 2)
        cy = atom.y + ATOM_RADIUS

        circle = Nokogiri::XML::Element.new("circle", doc)
        circle["cx"] = cx.to_s
        circle["cy"] = cy.to_s
        circle["r"] = ATOM_RADIUS.to_s
        circle["fill"] = "white"
        circle["stroke"] = "#0c4a3e"
        circle["stroke-width"] = "1.5"
        g.add_child(circle)

        text = Nokogiri::XML::Element.new("text", doc)
        text["x"] = cx.to_s
        text["y"] = (cy + 4).to_s
        text["text-anchor"] = "middle"
        text["font-family"] = "serif"
        text["font-size"] = "14"
        text["fill"] = "#0c4a3e"
        text.content = atom.element
        g.add_child(text)

        g
      end

      def render_bond(doc, from, to, kind)
        line = Nokogiri::XML::Element.new("line", doc)
        line["x1"] = (from.x + ATOM_RADIUS * 2).to_s
        line["y1"] = (from.y + ATOM_RADIUS).to_s
        line["x2"] = (to.x + ATOM_RADIUS * 2).to_s
        line["y2"] = (to.y + ATOM_RADIUS).to_s
        line["stroke"] = "#1a1a1a"
        line["stroke-width"] = bond_width(kind).to_s
        line
      end

      def bond_width(kind)
        case kind
        when :double then 3
        when :triple then 4
        when :quadruple then 5
        else 1.5
        end
      end
    end
  end
end
