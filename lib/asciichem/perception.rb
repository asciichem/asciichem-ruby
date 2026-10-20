# frozen_string_literal: true

module AsciiChem
  # The perception pass (TODO.v2/13 item 2): chemistry that the SYNTAX
  # leaves implicit, derived once here and consumed everywhere — the
  # linter, the canonicalizer, renderers, and the SMILES writer.
  #
  # Everything is a pure function of the model; nothing mutates.
  module Perception
    # Default valences per element (the common ground-state values;
    # multi-valent elements list their allowed valences in order).
    DEFAULT_VALENCES = {
      'H' => [1], 'B' => [3], 'C' => [4], 'N' => [3], 'O' => [2],
      'F' => [1], 'Al' => [3], 'Si' => [4], 'P' => [3, 5],
      'S' => [2, 4, 6], 'Cl' => [1], 'Br' => [1], 'I' => [1]
    }.freeze

    BOND_ORDER = {
      single: 1, double: 2, triple: 3, quadruple: 4,
      aromatic: 1, wedge: 1, hash: 1, dative: 1, wavy: 1
    }.freeze

    module_function

    # Perception runs over the neutral graph pair from
    # Structure::Graph.build: [atoms, edges].

    # Neighbour indexes of an atom, in edge order.
    def neighbours(atom_index, edges)
      edges.each_with_object([]) do |edge, acc|
        acc << edge.to if edge.from == atom_index
        acc << edge.from if edge.to == atom_index
      end
    end

    # Sum of explicit bond orders at an atom (wedge/hash/dative/wavy
    # bonds order as single; aromatic orders as 1 — Hückel alternation
    # is a ring-perception concern, not a bond-order sum concern).
    def bond_order_sum(atom_index, edges)
      edges.sum do |edge|
        next 0 unless edge.from == atom_index || edge.to == atom_index

        BOND_ORDER.fetch(edge.kind, 1)
      end
    end

    # Implicit hydrogens for an atom: the smallest default valence
    # that the explicit bond order fits, minus the bond order.
    # - Atoms that STATE hydrogens ([NH4+], [CH4]) return 0 — never
    #   add to what the source said.
    # - Charged atoms return nil: charge algebra on valence is
    #   element-specific and deferred until the perception pass grows
    #   one (wrong implicit hydrogens are worse than none).
    # - Elements without a table entry, or explicit orders exceeding
    #   every default, return nil — never invent.
    def implicit_hydrogens(atom, bond_order_sum)
      return 0 if atom.hydrogens
      return nil if atom.charge

      valences = DEFAULT_VALENCES[atom.element]
      return nil if valences.nil?

      fitting = valences.select { |v| v >= bond_order_sum }
      return nil if fitting.empty?

      fitting.min - bond_order_sum
    end

    # Six-membered cycles where every atom is sp2 (participates in a
    # double bond) or aromatic-flagged — the practical fused-system
    # rule: per-ring strict alternation can never see both rings of
    # naphthalene (the shared bond is single), but per-atom sp2 does.
    # Returns arrays of atom indexes, one per perceived ring, or an
    # empty list. Full Hückel pi-electron counting is a later slice.
    def aromatic_rings(atoms, edges)
      cycles = ring_cycles(edges, max_size: 6, atom_count: atoms.length)
        .select { |cycle| cycle.length == 6 }
      cycles.select { |cycle| cycle.all? { |i| sp2?(i, atoms, edges) } }
    end

    def sp2?(atom_index, atoms, edges)
      return true if atoms[atom_index].aromatic == true

      edges.any? do |edge|
        (edge.from == atom_index || edge.to == atom_index) && edge.kind == :double
      end
    end

    def bond_kind(a, b, edges)
      edge = edges.find do |e|
        (e.from == a && e.to == b) || (e.from == b && e.to == a)
      end
      edge&.kind
    end

    # Simple cycles up to max_size via DFS (molecules are small).
    def ring_cycles(edges, max_size:, atom_count:)
      found = []
      atom_count.times do |start|
        dfs_cycles(edges, start, start, [start], max_size, found)
      end
      found.uniq { |cycle| cycle.minmax }
    end

    def dfs_cycles(edges, start, current, path, max_size, found)
      neighbours(current, edges).each do |nb|
        next if nb == path[-2]

        if nb == start
          found << path.dup if path.length >= 3
        elsif !path.include?(nb) && path.length < max_size
          dfs_cycles(edges, start, nb, path + [nb], max_size, found)
        end
      end
    end
  end
end
