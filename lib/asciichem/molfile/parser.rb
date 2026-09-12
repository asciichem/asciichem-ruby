# frozen_string_literal: true

module AsciiChem
  module Molfile
    # V2000 molfile → Model::Molecule. Fixed-format blocks: header
    # (3 lines), counts line, atom block, bond block, property block.
    # Charges come from `M  CHG`, isotopes from the mass-difference
    # field or `M  ISO`, bond stereo codes 1/6 become wedge/hash.
    class Parser
      def initialize(text)
        @lines = text.lines.map(&:chomp)
      end

      def parse
        raise ParseError, "molfile too short" if @lines.length < 5

        atom_field = field(3, 0, 3)
        bond_field = field(3, 3, 3)
        unless atom_field.match?(/\A\d+\z/) && bond_field.match?(/\A\d+\z/)
          raise ParseError, "malformed counts line: #{@lines[3].inspect}"
        end
        atom_count = atom_field.to_i
        bond_count = bond_field.to_i

        atoms = parse_atoms(atom_count)
        bonds = parse_bonds(bond_count)
        properties = parse_properties

        apply_legacy_charge!(atoms)
        apply_charges!(atoms, properties[:charges])
        apply_isotopes!(atoms, properties[:isotopes])

        adjacency = Array.new(atoms.length) { {} }
        bonds.each do |bond|
          adjacency[bond[:from]][bond[:to]] = bond[:kind]
          adjacency[bond[:to]][bond[:from]] = bond[:kind]
        end

        # V2000 carries aromaticity on bonds (type 4); the model
        # carries it on atoms and bonds, so atoms touching an
        # aromatic bond are marked aromatic.
        bonds.each do |bond|
          next unless bond[:kind] == :aromatic

          atoms[bond[:from]].aromatic = true
          atoms[bond[:to]].aromatic = true
        end

        Model::Molecule.new(
          nodes: Structure::Linearizer.new(atoms: atoms, edges: adjacency_to_edges(adjacency)).nodes
        )
      end

      private

      def field(line_index, start, length)
        (@lines[line_index] || "")[start, length].to_s.strip
      end

      def parse_atoms(count)
        (1..count).map do |i|
          line_index = 3 + i
          line = @lines[line_index]
          raise ParseError, "truncated atom block (expected #{count} atoms)" if line.nil?

          x = line[0, 10].to_f
          y = line[10, 10].to_f
          z = line[20, 10].to_f
          element = line[31, 3].to_s.strip
          mass_diff = line[34, 2].to_i
          raise ParseError, "atom #{i} has no element symbol" if element.empty?

          Model::Atom.new(
            element: element,
            x2: x, y2: y, z2: z,
            isotope: isotope_from_mass_diff(element, mass_diff)
          )
        end
      end

      def parse_bonds(count)
        (1..count).map do |i|
          line = @lines[3 + atoms_count + i]
          raise ParseError, "truncated bond block (expected #{count} bonds)" if line.nil?

          from = line[0, 3].to_i - 1
          to = line[3, 3].to_i - 1
          type = line[6, 3].to_i
          stereo = line[9, 3].to_i
          raise ParseError, "bond #{i} has out-of-range atom indexes" if from.negative? || to.negative?

          { from: from, to: to, kind: bond_kind(type, stereo) }
        end
      end

      def parse_properties
        charges = {}
        isotopes = {}
        @lines.each do |line|
          if line.start_with?("M  CHG")
            parts = line[6..].split
            _count = parts[0].to_i
            parts[1..].each_slice(2) do |idx, charge|
              charges[idx.to_i - 1] = charge.to_i if idx && charge
            end
          elsif line.start_with?("M  ISO")
            parts = line[6..].split
            parts[1..].each_slice(2) do |idx, mass|
              isotopes[idx.to_i - 1] = mass.to_i if idx && mass
            end
          end
        end
        { charges: charges, isotopes: isotopes }
      end

      def bond_kind(type, stereo)
        return :wedge if stereo == 1
        return :hash if stereo == 6

        { 1 => :single, 2 => :double, 3 => :triple, 4 => :aromatic }[type] ||
          raise(ParseError, "unsupported molfile bond type #{type}")
      end

      # Pre-CHG charge column (0-based 36, 3): nonzero values 1..4
      # mean +1..+4, 5..7 mean -1..-3. `M  CHG` overrides.
      def apply_legacy_charge!(atoms)
        (1..field(3, 0, 3).to_i).each do |i|
          code = field(3 + i, 36, 3).to_i
          next if code.zero?

          charge = code <= 4 ? code : 4 - code
          sign = charge.negative? ? "-" : "+"
          atoms[i - 1].charge = charge.abs == 1 ? sign : "#{charge.abs}#{sign}"
        end
      end

      def apply_charges!(atoms, charges)
        charges.each do |index, value|
          sign = value.negative? ? "-" : "+"
          atoms[index].charge = value.abs == 1 ? sign : "#{value.abs}#{sign}"
        end
      end

      def apply_isotopes!(atoms, isotopes)
        isotopes.each do |index, mass|
          atoms[index].isotope = mass.to_s
        end
      end

      # Mass difference encodes isotopes relative to the rounded
      # average mass; mapping it unambiguously requires isotope
      # tables, so v1 defers isotopes to the explicit `M  ISO` block.
      def isotope_from_mass_diff(_element, mass_diff)
        nil
      end
      def atoms_count
        field(3, 0, 3).to_i
      end

      def adjacency_to_edges(adjacency)
        edges = []
        adjacency.each_with_index do |neighbors, index|
          neighbors.each { |to, kind| edges << Structure::Graph::Edge.new(from: index, to: to, kind: kind) if to > index }
        end
        edges
      end
    end
  end
end
