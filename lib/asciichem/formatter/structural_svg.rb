# frozen_string_literal: true

require 'nokogiri'

module AsciiChem
  module Formatter
    # Renders a Model tree as a 2D structural SVG diagram using
    # elkrb-computed atom positions. Bonds render as parallel lines
    # (single/double/triple/quadruple), wedges, hashes, or arrows
    # depending on kind.
    #
    # Falls back to the linear `Svg` formatter for inputs that don't
    # contain a molecule with bonds (formulae, reactions, etc.).
    class StructuralSvg < Base
      ATOM_RADIUS     = 14
      BOND_SPACING    = 4
      WEDGE_WIDTH     = 6
      HASH_DASH_COUNT = 5
      ATOM_COLORS = {
        'C' => '#1a1a1a',
        'H' => '#555',
        'O' => '#b91c1c',
        'N' => '#1e40af',
        'S' => '#a16207',
        'Cl' => '#16a34a',
        'F' => '#15803d',
        'Br' => '#7c2d12',
        'I' => '#6b21a8',
        'P' => '#a16207'
      }.freeze
      DEFAULT_ATOM_COLOR = '#0c4a3e'

      def visit_formula(formula)
        molecule = formula.nodes.find { |n| n.is_a?(AsciiChem::Model::Molecule) }
        return visit_formula_linear(formula) unless molecule

        has_bonds = molecule.nodes.any?(AsciiChem::Model::Bond)
        return visit_formula_linear(formula) unless has_bonds

        result = AsciiChem::Layout.layout(molecule)
        return visit_formula_linear(formula) if result.empty?

        render_svg(result)
      end

      private

      def visit_formula_linear(formula)
        AsciiChem::Formatter::Svg.new.render(formula)
      end

      def render_svg(result)
        doc = Nokogiri::XML::Document.new
        svg = build_svg_root(doc, result)
        bonds_first_then_atoms(result, doc, svg)
        doc.root = svg
        doc.to_xml
      end

      def build_svg_root(doc, result)
        svg = Nokogiri::XML::Element.new('svg', doc)
        svg['xmlns'] = 'http://www.w3.org/2000/svg'
        svg['width'] = result.width.to_s
        svg['height'] = result.height.to_s
        svg['viewBox'] = "0 0 #{result.width} #{result.height}"
        svg['role'] = 'img'
        title = Nokogiri::XML::Element.new('title', doc)
        title.content = title_text(result)
        svg.add_child(title)
        svg
      end

      def bonds_first_then_atoms(result, doc, svg)
        result.bonds.each do |bond|
          from = result.atoms_by_id[bond.from_id]
          to = result.atoms_by_id[bond.to_id]
          next unless from && to

          BondRenderer.new(doc, from, to, bond.kind).render_into(svg)
        end
        result.atoms.each do |atom|
          AtomRenderer.new(doc, atom).render_into(svg)
        end
      end

      def title_text(result)
        elements = result.atoms.map(&:element).uniq
        "#{result.atoms.length} atoms (#{elements.join(', ')})"
      end

      # Renders a single atom as a labeled circle. Color comes from
      # the per-element palette (CPK-inspired, simplified) so common
      # elements are visually distinguishable.
      class AtomRenderer
        def initialize(doc, atom)
          @doc = doc
          @atom = atom
        end

        def render_into(parent)
          group = Nokogiri::XML::Element.new('g', @doc)
          group.add_child(circle)
          group.add_child(label)
          parent.add_child(group)
        end

        private

        def circle
          el = Nokogiri::XML::Element.new('circle', @doc)
          el['cx'] = @atom.x.to_s
          el['cy'] = @atom.y.to_s
          el['r'] = StructuralSvg::ATOM_RADIUS.to_s
          el['fill'] = 'white'
          el['stroke'] = color
          el['stroke-width'] = '1.5'
          el
        end

        def label
          el = Nokogiri::XML::Element.new('text', @doc)
          el['x'] = @atom.x.to_s
          el['y'] = (@atom.y + 4).to_s
          el['text-anchor'] = 'middle'
          el['font-family'] = 'serif'
          el['font-size'] = '14'
          el['fill'] = color
          el.content = @atom.element
          el
        end

        def color
          StructuralSvg::ATOM_COLORS.fetch(@atom.element, StructuralSvg::DEFAULT_ATOM_COLOR)
        end
      end
      private_constant :AtomRenderer

      # Renders a single bond between two positioned atoms. Dispatches
      # on bond kind via a registry of Procs. Each Proc receives the
      # renderer (for its public line/offset helpers) and returns an
      # array of Nokogiri elements. Adding a new bond style is a new
      # Proc + one registry entry — no edits to existing renderers.
      class BondRenderer
        def initialize(doc, from_atom, to_atom, kind)
          @doc = doc
          @from = from_atom
          @to = to_atom
          @kind = kind
        end

        def render_into(parent)
          renderer = RENDERERS.fetch(@kind, RENDERERS[:single])
          Array(renderer.call(self)).each { |node| parent.add_child(node) }
        end

        # -- Public helpers used by the strategy Procs ---------------

        def base_line
          line(@from.x, @from.y, @to.x, @to.y)
        end

        def offset_line(distance)
          dx = @to.x - @from.x
          dy = @to.y - @from.y
          length = Math.sqrt((dx * dx) + (dy * dy))
          return nil if length.zero?

          px = -dy / length
          py = dx / length
          line(@from.x + (px * distance), @from.y + (py * distance),
               @to.x + (px * distance), @to.y + (py * distance))
        end

        def line(start_x, start_y, end_x, end_y)
          el = Nokogiri::XML::Element.new('line', @doc)
          el['x1'] = start_x.to_s
          el['y1'] = start_y.to_s
          el['x2'] = end_x.to_s
          el['y2'] = end_y.to_s
          el['stroke'] = '#1a1a1a'
          el['stroke-width'] = '1.5'
          el
        end

        def polygon(points, fill:)
          el = Nokogiri::XML::Element.new('polygon', @doc)
          el['points'] = points.map { |x, y| "#{x},#{y}" }.join(' ')
          el['fill'] = fill
          el
        end

        def from_point
          [@from.x, @from.y]
        end

        def to_point
          [@to.x, @to.y]
        end

        def unit_perpendicular
          dx = @to.x - @from.x
          dy = @to.y - @from.y
          length = Math.sqrt((dx * dx) + (dy * dy))
          return [0.0, 0.0] if length.zero?

          [-dy / length, dx / length]
        end

        # -- Strategy registry --------------------------------------
        #
        # Each entry maps a bond kind symbol to a Proc that takes the
        # renderer and returns an array of Nokogiri elements. Procs
        # use the public helpers above; nothing reaches into private
        # state.

        SPACING = StructuralSvg::BOND_SPACING
        WEDGE_HALF = StructuralSvg::WEDGE_WIDTH / 2.0
        HASH_COUNT = StructuralSvg::HASH_DASH_COUNT

        RENDERERS = {
          single: ->(r) { [r.base_line] },

          double: ->(r) { [-SPACING, 0, SPACING].map { |d| r.offset_line(d) }.compact },

          triple: ->(r) { [0, -SPACING * 1.5, SPACING * 1.5].map { |d| r.offset_line(d) }.compact },

          quadruple: ->(r) { [0, -SPACING, SPACING, -SPACING * 2.5].map { |d| r.offset_line(d) }.compact },

          wedge: lambda do |r|
            px, py = r.unit_perpendicular
            fx, fy = r.from_point
            tx, ty = r.to_point
            [r.polygon([[fx, fy],
                        [tx + (px * WEDGE_HALF), ty + (py * WEDGE_HALF)],
                        [tx - (px * WEDGE_HALF), ty - (py * WEDGE_HALF)]],
                       fill: '#1a1a1a')]
          end,

          hash: lambda do |r|
            px, py = r.unit_perpendicular
            fx, fy = r.from_point
            tx, ty = r.to_point
            dx = tx - fx
            dy = ty - fy
            nodes = []
            (1..HASH_COUNT).each do |i|
              t = i / HASH_COUNT.to_f
              cx = fx + (dx * t)
              cy = fy + (dy * t)
              w = WEDGE_HALF * t
              nodes << r.line(cx + (px * w), cy + (py * w),
                              cx - (px * w), cy - (py * w))
            end
            nodes
          end,

          dative: ->(r) { [r.base_line.tap { |l| l['marker-end'] = 'url(#aci-dative-arrow)' }] },

          wavy: lambda do |r|
            fx, fy = r.from_point
            tx, ty = r.to_point
            dx = tx - fx
            dy = ty - fy
            px, py = r.unit_perpendicular
            segments = 8
            amplitude = 3.0
            prev_x = fx
            prev_y = fy
            nodes = []
            (1..segments).each do |i|
              t = i / segments.to_f
              offset = Math.sin(t * Math::PI * 2) * amplitude
              x = fx + (dx * t) + (px * offset)
              y = fy + (dy * t) + (py * offset)
              nodes << r.line(prev_x, prev_y, x, y)
              prev_x = x
              prev_y = y
            end
            nodes
          end
        }.freeze
      end
      private_constant :BondRenderer
    end
  end
end
