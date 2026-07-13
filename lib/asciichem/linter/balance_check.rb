# frozen_string_literal: true

module AsciiChem
  module Linter
    # Verifies that a reaction is stoichiometrically balanced — the
    # atom counts on the reactants side equal those on the products
    # side. Coefficients and group multiplicities are applied.
    #
    # The check ignores electrons (`e^-`), conditions, and the arrow
    # kind. It treats unknown constructs conservatively: any molecule
    # it can't enumerate atoms for is skipped, not flagged.
    class BalanceCheck < Base
      register :balance

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
        reactants = count_side(reaction.reactants)
        products = count_side(reaction.products)
        return if reactants.nil? || products.nil?
        return if reactants == products

        diffs = compute_diffs(reactants, products)
        diagnostics << error(
          "Reaction is not balanced: #{diffs}",
          node: reaction
        )
      end

      # Returns a Hash mapping element symbol to count, or nil if any
      # molecule on the side couldn't be enumerated.
      def count_side(molecules)
        counts = Hash.new(0)
        molecules.each do |molecule|
          mol_counts = count_molecule(molecule)
          return nil if mol_counts.nil?

          mol_counts.each { |element, n| counts[element] += n }
        end
        counts
      end

      def count_molecule(molecule)
        coefficient = molecule.coefficient.to_i
        coefficient = 1 if coefficient.zero?
        raw = enumerate(molecule, 1)
        return nil if raw.nil?

        raw.transform_values { |v| v * coefficient }
      end

      # Recursive enumeration with a current multiplier.
      def enumerate(node, multiplier)
        case node
        when AsciiChem::Model::Atom
          sub = (node.subscript || "1").to_i
          sub = 1 if sub.zero?
          { node.element => sub * multiplier }
        when AsciiChem::Model::Molecule
          enumerate_many(node.nodes, multiplier)
        when AsciiChem::Model::Group
          mult = (node.multiplicity || "1").to_i
          mult = 1 if mult.zero?
          enumerate_many(node.nodes, multiplier * mult)
        else
          nil
        end
      end

      def enumerate_many(nodes, multiplier)
        result = Hash.new(0)
        nodes.each do |node|
          sub = enumerate(node, multiplier)
          return nil if sub.nil?

          sub.each { |element, n| result[element] += n }
        end
        result
      end

      def compute_diffs(reactants, products)
        all_elements = (reactants.keys + products.keys).uniq.sort
        all_elements.map do |element|
          r = reactants.fetch(element, 0)
          p = products.fetch(element, 0)
          next if r == p

          "#{element}: #{r} vs #{p}"
        end.compact.join(", ")
      end
    end
  end
end
