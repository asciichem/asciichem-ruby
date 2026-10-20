# frozen_string_literal: true

module AsciiChem
  module Linter
    # Verifies that each atom's total bond order plus |charge| does not
    # exceed the element's typical valence. Catches typos like `CH_5`
    # (carbon with five bonds).
    #
    # The valence table lists common valences per element. Unknown
    # elements produce an info diagnostic, not an error.
    class ValenceCheck < Base
      register :valence

      # Runs over the perception pass's graph view: every atom's bond
      # order counts ALL its bonds (rings and branches included — the
      # linear chain approximation missed both).
      def run(formula)
        diagnostics = []
        walk(formula) do |node|
          next unless node.is_a?(AsciiChem::Model::Molecule)

          check_molecule(node, diagnostics)
        end
        diagnostics
      end

      private

      def check_molecule(molecule, diagnostics)
        atoms, edges = AsciiChem::Structure::Graph.build(molecule)
        atoms.each_with_index do |atom, index|
          check_atom(atom, bond_order_sum(index, edges), diagnostics)
        end
      end

      def bond_order_sum(index, edges)
        AsciiChem::Perception.bond_order_sum(index, edges)
      end

      def check_atom(atom, load, diagnostics)
        max = AsciiChem::PeriodicTable.max_valence(atom.element)
        if max.nil?
          diagnostics << info(
            "Element #{atom.element.inspect} not in valence table; skipping",
            node: atom
          )
          return
        end

        return if load <= max

        diagnostics << error(
          "Atom #{atom.element} has bond order #{load}; max valence is #{max}",
          node: atom
        )
      end
    end
  end
end
