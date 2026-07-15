# frozen_string_literal: true

require 'elkrb'

module AsciiChem
  # 2D structural layout for molecules. Walks an
  # `AsciiChem::Model::Molecule`, builds an elkrb graph (atoms as
  # nodes, bonds as edges), runs a layout algorithm, and returns a
  # `Layout::Result` ready for SVG rendering.
  #
  # Three concerns, MECE:
  #
  # - `MoleculeWalker` — walks the AsciiChem tree, assigns stable IDs,
  #   produces a neutral atom+bond list. Knows nothing about elkrb.
  # - `GraphBuilder` — converts the walker's neutral list into an
  #   elkrb graph. Knows nothing about AsciiChem::Model.
  # - `ResultExtractor` — maps elkrb's laid-out positions back onto
  #   the walker's neutral list, producing a `Layout::Result`.
  #
  # Each is independently testable. New algorithms (ring detection,
  # stereo placement) slot in as additional visitors over the same
  # `Layout::Result`; no edits to the walker or extractor.
  module Layout
    ATOM_WIDTH  = 40.0
    ATOM_HEIGHT = 30.0
    PADDING     = 20.0

    PositionedAtom = Struct.new(:id, :element, :x, :y, :charge, :isotope,
                                :multiplicity, keyword_init: true)
    PositionedBond = Struct.new(:id, :kind, :from_id, :to_id, keyword_init: true)

    # Layout result: positioned atoms and bonds ready for rendering.
    Result = Struct.new(:atoms, :bonds, :width, :height, keyword_init: true) do
      def atoms_by_id
        @atoms_by_id ||= atoms.to_h { |a| [a.id, a] }
      end

      def empty?
        atoms.empty?
      end
    end

    # Empty result returned when layout is not applicable (e.g.
    # molecule has no atoms). Keeps callers from special-casing nil.
    def self.empty_result
      Result.new(atoms: [], bonds: [], width: 0.0, height: 0.0)
    end

    # Compute 2D positions for a molecule's atoms and bonds.
    # Returns a `Layout::Result`. Algorithm defaults to `layered`
    # (Sugiyama-style hierarchical) which is deterministic across
    # runs — essential for visual regression testing. Pass
    # `algorithm: "force"` for organic-looking layouts, with the
    # caveat that output may vary between runs.
    def self.layout(molecule, algorithm: 'layered')
      walker = MoleculeWalker.new(molecule)
      walk = walker.walk
      return empty_result if walk.atoms.empty?

      # If all atoms carry pre-positioned coordinates (e.g. from CML
      # x2/y2 attributes), skip elkrb and use the provided positions
      # directly. This preserves the molecule's original geometry when
      # round-tripping through CML.
      return pre_positioned_result(walk) if all_positioned?(walk)

      graph = GraphBuilder.new(walk).build(algorithm: algorithm)
      laid_out = Elkrb.layout(graph, algorithm: algorithm)
      ResultExtractor.new(laid_out, walk).extract
    end

    def self.all_positioned?(walk)
      walk.atoms.any? && walk.atoms.all? { |a| a.x2 && a.y2 }
    end
    private_class_method :all_positioned?

    # Build a Layout::Result directly from WalkAtoms that already
    # carry x2/y2 coordinates. No elkrb involved.
    def self.pre_positioned_result(walk)
      atoms = walk.atoms.map do |wa|
        PositionedAtom.new(
          id: wa.id,
          element: wa.element,
          x: wa.x2.to_f,
          y: wa.y2.to_f,
          charge: wa.charge,
          isotope: wa.isotope,
          multiplicity: wa.multiplicity
        )
      end
      bonds = walk.bonds.map do |wb|
        PositionedBond.new(id: wb.id, kind: wb.kind,
                           from_id: wb.from_id, to_id: wb.to_id)
      end
      max_x = atoms.map(&:x).max || 0.0
      max_y = atoms.map(&:y).max || 0.0
      Result.new(atoms: atoms, bonds: bonds,
                 width: max_x + PADDING,
                 height: max_y + PADDING)
    end
    private_class_method :pre_positioned_result

    # Walks an AsciiChem::Model::Molecule in source order, assigning
    # deterministic IDs and emitting atoms + bonds. Pure; no elkrb
    # dependency.
    class MoleculeWalker
      attr_reader :atoms, :bonds

      def initialize(molecule)
        @molecule = molecule
        @atoms = []
        @bonds = []
        @atom_counter = IdCounter.new('a')
        @bond_counter = IdCounter.new('b')
        @pending_bond = nil
        @last_atom_id = nil
        @atom_id_by_object_id = {}
      end

      # Returns a WalkResult — the neutral atom+bond list with
      # element/charge/etc preserved from the source molecule.
      def walk
        walk_nodes(@molecule.nodes)
        emit_ring_bonds
        WalkResult.new(atoms: @atoms, bonds: @bonds)
      end

      # Emit a bond for each ring-closure pair. Uses
      # `AsciiChem::RingBonds.each_in` so the algorithm is shared
      # with the CML adapter and the linter.
      def emit_ring_bonds
        AsciiChem::RingBonds.each_in(@molecule) do |ring_bond|
          from_id = @atom_id_by_object_id[ring_bond.from_atom.object_id]
          to_id = @atom_id_by_object_id[ring_bond.to_atom.object_id]
          next unless from_id && to_id

          @bonds << WalkBond.new(
            id: @bond_counter.next,
            kind: :single,
            from_id: from_id,
            to_id: to_id
          )
        end
      end

      private

      def walk_nodes(nodes)
        nodes.each do |node|
          case node
          when AsciiChem::Model::Atom
            emit_atom(node)
          when AsciiChem::Model::Bond
            @pending_bond = node
          when AsciiChem::Model::Group, AsciiChem::Model::Molecule
            walk_nodes(node.nodes)
          end
        end
      end

      def emit_atom(atom)
        id = @atom_counter.next
        @atom_id_by_object_id[atom.object_id] = id
        @atoms << WalkAtom.new(
          id: id,
          element: atom.element,
          charge: atom.charge,
          isotope: atom.isotope,
          multiplicity: atom.subscript,
          x2: atom.x2,
          y2: atom.y2
        )
        emit_pending_bond(id) if @pending_bond && @last_atom_id
        @last_atom_id = id
        @pending_bond = nil
      end

      def emit_pending_bond(next_atom_id)
        @bonds << WalkBond.new(
          id: @bond_counter.next,
          kind: @pending_bond.kind,
          from_id: @last_atom_id,
          to_id: next_atom_id
        )
      end
    end
    private_constant :MoleculeWalker

    # Neutral walker output. Decouples the walker from both elkrb and
    # the canonical model — the same walk could feed any future
    # graph-based renderer.
    WalkAtom = Struct.new(:id, :element, :charge, :isotope, :multiplicity, :x2, :y2, keyword_init: true)
    WalkBond = Struct.new(:id, :kind, :from_id, :to_id, keyword_init: true)
    WalkResult = Struct.new(:atoms, :bonds, keyword_init: true)
    private_constant :WalkAtom, :WalkBond, :WalkResult

    # Builds an elkrb graph from a walker's neutral output. Knows
    # only about elkrb's Node/Edge/Graph classes and the Layout
    # dimension constants.
    class GraphBuilder
      def initialize(walk)
        @walk = walk
      end

      def build(algorithm:)
        children = @walk.atoms.map { |a| elkrb_node(a) }
        edges = @walk.bonds.map { |b| elkrb_edge(b) }
        Elkrb::Graph::Graph.new(
          id: 'root',
          children: children,
          edges: edges,
          layout_options: Elkrb::Graph::LayoutOptions.new(algorithm: algorithm)
        )
      end

      private

      def elkrb_node(atom)
        Elkrb::Graph::Node.new(
          id: atom.id,
          width: Layout::ATOM_WIDTH,
          height: Layout::ATOM_HEIGHT,
          properties: { 'element' => atom.element,
                        'charge' => atom.charge,
                        'isotope' => atom.isotope,
                        'multiplicity' => atom.multiplicity }
        )
      end

      def elkrb_edge(bond)
        Elkrb::Graph::Edge.new(
          id: bond.id,
          sources: [bond.from_id],
          targets: [bond.to_id],
          properties: { 'kind' => bond.kind.to_s }
        )
      end
    end
    private_constant :GraphBuilder

    # Maps an elkrb laid-out graph back onto the walker's neutral
    # atom+bond list, producing a `Layout::Result`. Positions come
    # from elkrb; everything else (element, charge, kind) comes from
    # the walker — elkrb doesn't carry chemistry semantics.
    class ResultExtractor
      def initialize(laid_out, walk)
        @laid_out = laid_out
        @walk = walk
      end

      def extract
        position_by_id = build_position_map
        atoms = build_positioned_atoms(position_by_id)
        bonds = build_positioned_bonds
        Layout::Result.new(
          atoms: atoms,
          bonds: bonds,
          width: @laid_out.width.to_f + Layout::PADDING,
          height: @laid_out.height.to_f + Layout::PADDING
        )
      end

      private

      def build_position_map
        @laid_out.children.to_h do |node|
          [node.id, [node.x.to_f, node.y.to_f]]
        end
      end

      def build_positioned_atoms(position_by_id)
        @walk.atoms.map do |walk_atom|
          x, y = position_by_id.fetch(walk_atom.id, [0.0, 0.0])
          Layout::PositionedAtom.new(
            id: walk_atom.id,
            element: walk_atom.element,
            x: x,
            y: y,
            charge: walk_atom.charge,
            isotope: walk_atom.isotope,
            multiplicity: walk_atom.multiplicity
          )
        end
      end

      def build_positioned_bonds
        @walk.bonds.map do |walk_bond|
          Layout::PositionedBond.new(
            id: walk_bond.id,
            kind: walk_bond.kind,
            from_id: walk_bond.from_id,
            to_id: walk_bond.to_id
          )
        end
      end
    end
    private_constant :ResultExtractor

    # Per-build ID counter. Format: `prefix + N` (e.g. "a1", "b2").
    # Walker instances are per-translation so IDs reset cleanly.
    class IdCounter
      def initialize(prefix)
        @prefix = prefix
        @counter = 0
      end

      def next
        @counter += 1
        "#{@prefix}#{@counter}"
      end
    end
    private_constant :IdCounter
  end
end
