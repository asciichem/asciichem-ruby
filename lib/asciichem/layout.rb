# frozen_string_literal: true

require "elkrb"

module AsciiChem
  # 2D structural layout for molecules. Uses elkrb (Eclipse Layout
  # Kernel for Ruby) to compute atom positions, then renders the
  # positioned graph as SVG.
  #
  # The layout module converts a Model::Molecule into an elkrb graph,
  # runs the layout algorithm, and returns positioned atoms + bonds.
  # The SVG formatter (or any future renderer) consumes the result.
  module Layout
    ATOM_WIDTH  = 40.0
    ATOM_HEIGHT = 30.0
    ATOM_SPACING = 60.0

    PositionedAtom = Struct.new(:id, :element, :x, :y, :charge, :isotope, keyword_init: true)
    PositionedBond = Struct.new(:kind, :from_id, :to_id, keyword_init: true)

    # Layout result: positioned atoms and bonds ready for rendering.
    Result = Struct.new(:atoms, :bonds, :width, :height, keyword_init: true) do
      def atoms_by_id
        @atoms_by_id ||= atoms.each_with_object({}) { |a, memo| memo[a.id] = a }
      end
    end

    # Compute 2D positions for a molecule's atoms and bonds.
    # Returns a Layout::Result.
    def self.layout(molecule, algorithm: "force")
      builder = GraphBuilder.new(molecule)
      graph = builder.build
      laid_out = Elkrb.layout(graph, algorithm: algorithm)
      extract_result(laid_out, molecule, builder)
    end

    # -- Internal: graph construction --------------------------------

    # Converts a Model::Molecule into an elkrb graph hash. Each atom
    # becomes a node; each bond becomes an edge.
    class GraphBuilder
      attr_reader :atom_ids

      def initialize(molecule)
        @molecule = molecule
        @atom_ids = {}
        @counter = 0
      end

      def build
        children = collect_atoms.map do |atom, id|
          {
            id: id,
            width: Layout::ATOM_WIDTH,
            height: Layout::ATOM_HEIGHT,
            label: atom.element
          }
        end

        edges = collect_bonds.map do |bond|
          {
            id: "e#{@counter += 1}",
            sources: [bond_atom_ref(bond, 0)],
            targets: [bond_atom_ref(bond, 1)]
          }
        end

        {
          id: "root",
          layoutOptions: { "elk.algorithm" => "force" },
          children: children,
          edges: edges
        }
      end

      private

      def collect_atoms
        result = []
        walk_atoms(@molecule) { |atom| result << [atom, assign_id(atom)] }
        result
      end

      def collect_bonds
        @molecule.nodes.select { |n| n.is_a?(AsciiChem::Model::Bond) }
      end

      def walk_atoms(node)
        case node
        when AsciiChem::Model::Molecule
          node.nodes.each { |child| walk_atoms(child) { |a| yield a } }
        when AsciiChem::Model::Group
          node.nodes.each { |child| walk_atoms(child) { |a| yield a } }
        when AsciiChem::Model::Atom
          yield node
        end
      end

      def assign_id(atom)
        @counter += 1
        id = "a#{@counter}"
        @atom_ids[atom.object_id] = id
        id
      end

      def bond_atom_ref(_bond, _index)
        # Bonds in AsciiChem::Model are positional, not ID-based.
        # For layout, we connect consecutive atoms. elkrb needs
        # source/target IDs. This is a simplification — for branched
        # molecules, a full graph traversal would be needed.
        nil
      end
    end

    private_constant :GraphBuilder

    # -- Internal: result extraction ---------------------------------

    def self.extract_result(laid_out, molecule, builder)
      atoms = []
      bonds = []

      if laid_out.is_a?(Hash)
        laid_out_children = laid_out[:children] || laid_out["children"] || []
      else
        laid_out_children = laid_out.children || []
      end

      # Map laid-out positions back to model atoms.
      model_atoms = []
      walk_atoms_for_layout(molecule) { |a| model_atoms << a }

      laid_out_children.each_with_index do |node, idx|
        model_atom = model_atoms[idx]
        next unless model_atom

        x = extract_float(node, :x) || extract_float(node, "x") || (idx * ATOM_SPACING)
        y = extract_float(node, :y) || extract_float(node, "y") || 0.0

        atoms << PositionedAtom.new(
          id: node_id(node),
          element: model_atom.element,
          x: x,
          y: y,
          charge: model_atom.charge,
          isotope: model_atom.isotope
        )
      end

      # Extract bonds from the model (positional).
      prev_id = nil
      molecule.nodes.each do |node|
        case node
        when AsciiChem::Model::Atom
          prev_id = atoms.any? { |a| a.element == node.element } ? find_atom_id(atoms, node) : nil
        when AsciiChem::Model::Bond
          if prev_id
            next_id = atoms[atoms.index { |a| a.id == prev_id } + 1]&.id
            bonds << PositionedBond.new(kind: node.kind, from_id: prev_id, to_id: next_id) if next_id
          end
        end
      end

      max_x = atoms.map { |a| a.x }.max || 0
      max_y = atoms.map { |a| a.y }.max || 0

      Result.new(
        atoms: atoms,
        bonds: bonds,
        width: max_x + ATOM_WIDTH + 20,
        height: max_y + ATOM_HEIGHT + 20
      )
    end

    def self.walk_atoms_for_layout(node)
      case node
      when AsciiChem::Model::Molecule
        node.nodes.each { |child| walk_atoms_for_layout(child) { |a| yield a } }
      when AsciiChem::Model::Group
        node.nodes.each { |child| walk_atoms_for_layout(child) { |a| yield a } }
      when AsciiChem::Model::Atom
        yield node
      end
    end

    def self.extract_float(node, key)
      val = node.is_a?(Hash) ? node[key] : node.send(key) rescue nil
      val&.to_f
    end

    def self.node_id(node)
      node.is_a?(Hash) ? (node[:id] || node["id"]) : node.id
    end

    def self.find_atom_id(atoms, model_atom)
      found = atoms.find { |a| a.element == model_atom.element }
      found&.id
    end

    private_class_method :extract_result, :walk_atoms_for_layout,
                         :extract_float, :node_id, :find_atom_id
  end
end
