# frozen_string_literal: true

module AsciiChem
  module Molfile
    # Model molecule → V2000 molfile. Authored x2/y2 coordinates are
    # used when present; otherwise a deterministic 2D layout is
    # computed (Layout walks atoms in the same order as
    # Structure::Graph, so positions map by index). Charges and
    # isotopes are emitted as `M  CHG` / `M  ISO` property lines.
    class Writer
      BOND_TYPES = {
        single: 1, double: 2, triple: 3, aromatic: 4,
        wedge: 1, hash: 1
      }.freeze
      BOND_STEREO = { wedge: 1, hash: 6 }.freeze

      def initialize(molecule, name: nil)
        @molecule = molecule
        @name = name
      end

      def write
        atoms, edges = Structure::Graph.build(@molecule)
        raise ParseError, "molecule has no bonds — a formula is not a structure" if edges.empty?

        lines = []
        lines << @name.to_s
        lines << "  AsciiChem"
        lines << ""
        lines << format("%3d%3d  0  0  0  0  0  0  0  0999 V2000", atoms.length, edges.length)

        layout = nil
        atoms.each_with_index do |atom, index|
          x, y = coordinates(atom, index, atoms)
          lines << format("%10.4f%10.4f%10.4f %-3s 0  0  0  0  0  0  0  0  0  0  0  0",
                          x, y, atom.z2 || 0.0, atom.element)
        end

        edges.each do |edge|
          type = BOND_TYPES.fetch(edge.kind) do
            raise ParseError, "#{edge.kind} bonds have no molfile V2000 type"
          end
          stereo = BOND_STEREO.fetch(edge.kind, 0)
          lines << format("%3d%3d%3d%3d  0  0  0  0  0  0  0",
                          edge.from + 1, edge.to + 1, type, stereo)
        end

        lines << property_line("M  CHG", charge_pairs(atoms))
        lines << property_line("M  ISO", isotope_pairs(atoms))
        lines << "M  END"
        lines.compact.join("\n") << "\n"
      end

      private

      # Authored coordinates win; otherwise positions from the
      # deterministic 2D layout (same walk order as the graph).
      def coordinates(atom, index, atoms)
        return [atom.x2, atom.y2] if atom.x2 && atom.y2

        @layout ||= AsciiChem::Layout.layout(@molecule)
        placed = @layout.atoms[index]
        placed ? [placed.x, placed.y] : [0.0, 0.0]
      end

      def charge_pairs(atoms)
        atoms.each_with_index
             .filter_map { |atom, i| [i + 1, charge_value(atom.charge)] if atom.charge }
      end

      def isotope_pairs(atoms)
        atoms.each_with_index
             .filter_map { |atom, i| [i + 1, atom.isotope.to_i] if atom.isotope }
      end

      # The model's number-then-sign charge ("2+") → signed integer.
      def charge_value(charge)
        count = charge[/\A\d+/]&.to_i || 1
        charge.end_with?("-") ? -count : count
      end

      def property_line(prefix, pairs)
        return nil if pairs.empty?

        pairs.reduce(+"#{prefix}%3d" % pairs.length) do |line, (idx, value)|
          line << format("%4d%4d", idx, value)
        end
      end
    end
  end
end
