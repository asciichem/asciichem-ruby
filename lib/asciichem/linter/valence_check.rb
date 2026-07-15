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

      def run(formula)
        diagnostics = []
        # Walk molecules so we know which atom is the bonding context.
        walk(formula) do |node|
          next unless node.is_a?(AsciiChem::Model::Molecule)

          check_molecule(node, diagnostics)
        end
        diagnostics
      end

      private

      def check_molecule(molecule, diagnostics)
        # Walk the molecule's nodes; pair each atom with the bonds
        # immediately adjacent to it in the chain.
        bond_count = 0
        molecule.children.each do |node|
          case node
          when AsciiChem::Model::Bond
            bond_count += bond_order(node)
          when AsciiChem::Model::Atom
            check_atom(node, bond_count, diagnostics)
            bond_count = 0
          when AsciiChem::Model::Group
            # Group's internal bonds aren't visible here; reset.
            bond_count = 0
          end
        end
      end

      def bond_order(bond)
        case bond.kind
        when :single then 1
        when :double then 2
        when :triple then 3
        when :quadruple then 4
        else 1
        end
      end

      def check_atom(atom, incoming_bond_order, diagnostics)
        max = AsciiChem::PeriodicTable.max_valence(atom.element)
        if max.nil?
          diagnostics << info(
            "Element #{atom.element.inspect} not in valence table; skipping",
            node: atom
          )
          return
        end

        # Approximate: an atom with subscript has multiplicity, not
        # extra bonds. We use incoming_bond_order + |charge| as the
        # rough load.
        charge = atom.charge.to_s
        charge_value = parse_charge_magnitude(charge)
        load = incoming_bond_order + charge_value
        return if load <= max

        diagnostics << error(
          "Atom #{atom.element} has load #{load} (bond order #{incoming_bond_order} + charge #{charge_value}); max valence is #{max}",
          node: atom
        )
      end

      def parse_charge_magnitude(charge)
        return 0 if charge.nil? || charge.empty?

        match = charge.match(/\A(?<n>\d*)(?<sign>[+-])\z/) ||
                charge.match(/\A(?<sign>[+-])(?<n>\d*)\z/)
        return 0 unless match

        n = match[:n].empty? ? 1 : match[:n].to_i
        n
      end
    end
  end
end
