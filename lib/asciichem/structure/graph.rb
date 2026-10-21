# frozen_string_literal: true

module AsciiChem
  module Structure
    # Model molecule → neutral graph. Bond tokens between consecutive
    # atoms become edges (pending-bond semantics, same as the Layout
    # walker); ring-closure digits become edges via AsciiChem::RingBonds.
    module Graph
      Edge = Struct.new(:from, :to, :kind, :direction, keyword_init: true)

      class << self
        # Returns [atoms, edges] where atoms is the atom array in walk
        # order and edges is an array of Edge with array indexes.
        #
        # Tolerant on purpose: the linter counts exactly the bonds that
        # are written. Structure writers use `build!`, which declines
        # formula-style adjacency (see there).
        def build(molecule)
          atoms, edges, = build_with_adjacency(molecule)
          [atoms, edges]
        end

        # Structure writers only. Text adjacency — atoms with no bond
        # token between them (`CCO`, the undashed spacers in
        # `C1=CC=CC=C1`) — is formula notation, not a bond; mixing it
        # with explicit bonds silently fragments the graph (a benzene
        # ring written as a disconnected C4+C2 pair), so the strict
        # build declines when adjacency is present and the final graph
        # is disconnected. SMILES models never trip this: their parser
        # always bonds every continuation (branch reconnection crosses
        # as a ring-closure digit), so the graph is connected even
        # though the flat node list has token-less boundaries — and an
        # explicit multi-component model (a salt written `A.B`) has no
        # adjacency at all.
        def build!(molecule)
          atoms, edges, adjacency_pairs = build_with_adjacency(molecule)
          return [atoms, edges] if adjacency_pairs.empty? || connected?(atoms.length, edges)

          raise ParseError,
                'adjacent atoms have no explicit bond token — a formula ' \
                'is not a structure. Write explicit bonds (C-C) or ingest ' \
                'the structure from SMILES/molfile.'
        end

        private

        def build_with_adjacency(molecule)
          atoms = []
          edges = []
          index_by_object_id = {}
          adjacency_pairs = []
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
                if pending
                  edges << Edge.new(from: last, to: index, kind: pending.kind,
                                    direction: pending.direction) if last
                elsif last
                  adjacency_pairs << [last, index]
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

          [atoms, edges, adjacency_pairs]
        end

        def connected?(atom_count, edges)
          return true if atom_count <= 1

          neighbours = Array.new(atom_count) { [] }
          edges.each do |edge|
            neighbours[edge.from] << edge.to
            neighbours[edge.to] << edge.from
          end
          seen = [false] * atom_count
          seen[0] = true
          queue = [0]
          until queue.empty?
            current = queue.shift
            neighbours[current].each do |n|
              next if seen[n]

              seen[n] = true
              queue << n
            end
          end
          seen.all?
        end
      end
    end
  end
end
