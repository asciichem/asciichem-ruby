# frozen_string_literal: true

module AsciiChem
  module Linter
    # Verifies charge conservation in reactions: total formal charge
    # on the reactants side equals total on the products side.
    #
    # Parallel to BalanceCheck (which validates atom conservation).
    # Both are needed because a reaction can be stoichiometrically
    # balanced but charge-imbalanced (e.g. `H+ + OH- -> H_2O+`).
    #
    # Charges come from Atom#charge (e.g. "2+", "-1", "+"). Coefficients
    # and group multiplicities are applied. Reactions without charges
    # on either side pass (no diagnostic).
    class ChargeBalanceCheck < Base
      register :charge_balance

      def run(formula)
        diagnostics = []
        walk(formula) do |node|
          next unless node.is_a?(AsciiChem::Model::Reaction)

          check_reaction(node, diagnostics)
        end
        diagnostics
      end

      private

      def check_reaction(reaction, diagnostics)
        reactants = total_charge(reaction.reactants)
        products = total_charge(reaction.products)
        return if reactants.nil? || products.nil?
        return if reactants == products

        diagnostics << error(
          "Reaction charge is not balanced: reactants #{format_charge(reactants)} " \
          "vs products #{format_charge(products)}",
          node: reaction
        )
      end

      # Sum formal charges on one side of the reaction. Returns nil
      # if any molecule couldn't be enumerated (mirrors BalanceCheck's
      # conservative skip behaviour).
      def total_charge(molecules)
        total = 0
        molecules.each do |molecule|
          charge = molecule_charge(molecule)
          return nil if charge.nil?

          total += charge
        end
        total
      end

      # Charge on a single molecule (with coefficient applied).
      def molecule_charge(molecule)
        coefficient = molecule.coefficient&.to_i
        coeff = coefficient && coefficient.positive? ? coefficient : 1
        inner = enumerate_charge(molecule)
        return nil if inner.nil?

        coeff * inner
      end

      # Recursively sum atom charges, applying group multiplicities.
      def enumerate_charge(node)
        case node
        when AsciiChem::Model::Atom
          parse_charge_value(node.charge)
        when AsciiChem::Model::Group
          mult = node.multiplicity&.to_i
          multiplier = mult && mult.positive? ? mult : 1
          inner = sum_nodes_charge(node.nodes)
          return nil if inner.nil?

          inner * multiplier
        when AsciiChem::Model::Molecule
          sum_nodes_charge(node.nodes)
        else
          0
        end
      end

      def sum_nodes_charge(nodes)
        total = 0
        nodes.each do |node|
          charge = enumerate_charge(node)
          return nil if charge.nil?

          total += charge
        end
        total
      end

      # Parse a charge string like "2+", "+", "-1", "2-" into an
      # integer. Returns 0 for nil/empty (atom has no charge).
      def parse_charge_value(charge)
        return 0 if charge.nil? || charge.to_s.empty?

        match = charge.to_s.match(/\A(?<n>\d*)(?<sign>[+-])\z/) ||
                charge.to_s.match(/\A(?<sign>[+-])(?<n>\d*)\z/)
        return 0 unless match

        n = match[:n].empty? ? 1 : match[:n].to_i
        match[:sign] == "+" ? n : -n
      end

      def format_charge(value)
        return "0" if value.zero?

        value.positive? ? "+#{value}" : value.to_s
      end
    end
  end
end
