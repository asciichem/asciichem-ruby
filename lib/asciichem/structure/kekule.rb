# frozen_string_literal: true

module AsciiChem
  module Structure
    # The text projection of an aromatic ring is its Kekulé form:
    # aromatic text bonds are unparseable (the Lewis lone-pair prefix
    # owns `:` in every position an aromatic bond could occupy — the
    # adjacency form `Fe^(II)::O.` is the corpus proof,
    # asciichem-ruby#188), so `c1ccccc1` renders as `C1=CC=CC=C1`.
    #
    # A Kekulé assignment is a perfect matching on the component's
    # atoms (each atom exactly one double bond), found by
    # deterministic backtracking in Graph edge order (include before
    # skip) so all runtimes derive identical output. Components with
    # no perfect matching (odd rings like furan) stay out of the
    # projection and keep the aromatic rendering (the spec'd text
    # loss). The model itself is never touched — the projection is a
    # render-time view, exactly like perception.
    module Kekule
      module_function

      # The Kekulé projection of `molecule`'s aromatic bonds:
      # {Model::Bond => :double | :single} keyed by node identity
      # (compare_by_identity — nodes use value equality, so ordinary
      # hashing would collide same-kind bonds). Every chain bond of a
      # kekulized component gets its assigned kind (the
      # single-assigned bonds must also lose the aromatic glyph or the
      # text wouldn't re-parse). Ring-closure edges carry no bond
      # token (digits are single by grammar). Bonds of components with
      # no perfect matching (odd rings) keep the aromatic glyph (the
      # spec'd text loss).
      def bond_kinds(molecule)
        _atoms, edges = Graph.build(molecule)
        aromatic = edges.select { |edge| edge.kind == :aromatic }
        kinds = {}.compare_by_identity
        return kinds if aromatic.empty?

        components(aromatic).each do |component|
          indices = matching(component)
          next unless indices

          component.each_with_index do |edge, index|
            next unless edge.bond

            kinds[edge.bond] = indices.include?(index) ? :double : :single
          end
        end
        kinds
      end

      # Connected components of the aromatic subgraph.
      def components(aromatic)
        found = []
        remaining = aromatic.dup
        until remaining.empty?
          seed = remaining.shift
          component = [seed]
          atoms = [seed.from, seed.to]
          grew = true
          while grew
            grew = false
            remaining.reject! do |edge|
              next false unless atoms.include?(edge.from) || atoms.include?(edge.to)

              component << edge
              atoms << edge.from
              atoms << edge.to
              grew = true
              true
            end
          end
          found << component
        end
        found
      end

      # Indices of a perfect matching over the component's atoms (each
      # atom incident to exactly one chosen edge), or nil.
      def matching(component)
        atom_set = component.flat_map { |edge| [edge.from, edge.to] }.uniq
        counts = Hash.new(0)
        chosen = []
        found = nil
        search(component, 0, chosen, counts, atom_set) { |indices| found = indices }
        found
      end

      def search(component, index, chosen, counts, atom_set, &block)
        if index == component.length
          block.call(chosen.dup) if atom_set.all? { |atom| counts[atom] == 1 }
          return
        end
        edge = component[index]
        unless counts[edge.from] == 1 || counts[edge.to] == 1
          counts[edge.from] += 1
          counts[edge.to] += 1
          chosen << index
          search(component, index + 1, chosen, counts, atom_set, &block)
          chosen.pop
          counts[edge.from] -= 1
          counts[edge.to] -= 1
        end
        search(component, index + 1, chosen, counts, atom_set, &block)
      end
    end
  end
end
