# frozen_string_literal: true

module AsciiChem
  module Linter
    # Cross-checks identifier values against the molecule they
    # annotate, where checkable offline:
    #
    # - InChI: the formula layer's element counts must match the
    #   molecule's composition (error — the formula layer is
    #   authoritative).
    # - SMILES: the element set must agree with the molecule's
    #   elements (warning — implicit hydrogens are tolerated, so only
    #   set membership is checkable without a full parser).
    #
    # Structural equality (stereo, isotopes, tautomers) needs the
    # InChI engine (TODO.v2 10) or resolution (TODO.v2 07 Layer 2)
    # and is out of scope here.
    #
    # Identifiers describe the *substance*, not the stoichiometric
    # multiplier, so comparisons use the molecule's composition
    # without its coefficient.
    class IdentifierConsistencyCheck < Base
      register :identifier_consistency

      def run(formula)
        diagnostics = []
        walk(formula) do |node|
          next unless node.is_a?(AsciiChem::Model::Molecule)

          check_inchi(node, diagnostics)
          check_smiles(node, diagnostics)
        end
        diagnostics
      end

      private

      def check_inchi(molecule, diagnostics)
        counts = molecule.element_counts(with_coefficient: false)
        identifiers_for(molecule, "inchi").each do |identifier|
          inchi_counts = AsciiChem::Identifiers::Inchi.formula_counts(identifier.value)
          next if inchi_counts.nil? # malformed — format check reports it

          diffs = composition_diffs(counts, inchi_counts)
          next if diffs.empty?

          diagnostics << error(
            "InChI formula #{formula_string(inchi_counts)} does not match molecule " \
            "#{formula_string(counts)}: #{diffs}",
            node: molecule
          )
        end
      end

      def check_smiles(molecule, diagnostics)
        counts = molecule.element_counts(with_coefficient: false)
        identifiers_for(molecule, "smiles").each do |identifier|
          message = smiles_mismatch(counts, identifier)
          next if message.nil?

          diagnostics << warning(message, node: molecule)
        end
      end

      # nil when the SMILES element set agrees with the molecule
      # (implicit hydrogens tolerated); a message otherwise.
      def smiles_mismatch(counts, identifier)
        smiles_elements = AsciiChem::Identifiers::Smiles.element_set(identifier.value)
        return nil if smiles_elements.nil? # unanalysable — format check reports it

        elements = counts.keys
        extra = (smiles_elements - elements).sort
        missing = (elements - smiles_elements - ["H"]).sort
        return nil if extra.empty? && missing.empty?

        "SMILES elements #{smiles_elements.inspect} do not match molecule " \
          "#{formula_string(counts)}: unexpected #{extra.inspect}, missing #{missing.inspect}"
      end

      def identifiers_for(molecule, convention)
        molecule.identifiers.select { |identifier| identifier.convention.to_s == convention }
      end

      def composition_diffs(molecule_counts, inchi_counts)
        keys = (molecule_counts.keys + inchi_counts.keys).uniq.sort
        keys.filter_map do |element|
          actual = molecule_counts.fetch(element, 0)
          expected = inchi_counts.fetch(element, 0)
          next if actual == expected

          "#{element}: #{actual} vs #{expected}"
        end.join(", ")
      end

      def formula_string(counts)
        counts.sort.map { |element, count| count == 1 ? element : "#{element}#{count}" }.join
      end
    end
  end
end
