# frozen_string_literal: true

module AsciiChem
  module Structure
    # Model molecule → neutral graph. Bond tokens between consecutive
    # atoms become edges (pending-bond semantics, same as the Layout
    # walker); ring-closure digits become edges via AsciiChem::RingBonds.
    module Graph
      Edge = Struct.new(:from, :to, :kind, keyword_init: true)

      class << self
        # Returns [atoms, edges] where atoms is the atom array in
        # walk order and edges is an array of Edge with array indexes.
        def build(molecule)
          atoms = []
          edges = []
          index_by_object_id = {}
          pending = nil
          last = nil

          walk = lambda do |nodes|
            nodes.each do |node|
              case node
              when AsciiChem::Model::Atom
                index = atoms.length
                # Atoms override == with value equality (benzene's
                # carbons are all equal), so identity is by object_id —
                # same as the Layout walker.
                index_by_object_id[node.object_id] = index
                atoms << node
                if pending && last
                  edges << Edge.new(from: last, to: index, kind: pending.kind)
                end
                last = index
                pending = nil
              when AsciiChem::Model::Bond
                pending = node
              when AsciiChem::Model::Group, AsciiChem::Model::Molecule
                walk.call(node.nodes)
              end
            end
          end
          walk.call(molecule.nodes)

          AsciiChem::RingBonds.each_in(molecule) do |ring|
            from = index_by_object_id[ring.from_atom.object_id]
            to = index_by_object_id[ring.to_atom.object_id]
            next unless from && to

            # Ring-closure digits carry no kind; the default bond rule
            # (aromatic between aromatic atoms, otherwise single)
            # applies — the same rule the SMILES parser uses.
            kind = ring.from_atom.aromatic && ring.to_atom.aromatic ? :aromatic : :single
            edges << Edge.new(from: from, to: to, kind: kind)
          end

          [atoms, edges]
        end
      end
    end
  end
end
