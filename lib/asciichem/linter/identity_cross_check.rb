# frozen_string_literal: true

module AsciiChem
  module Linter
    # Structural cross-check of identity annotations (TODO.v2 10).
    # Where IdentifierConsistencyCheck compares offline-analysable
    # layers (formula composition), this check derives the InChI of
    # the drawn structure via the configured engine and compares it
    # to the annotated `@inchi`/`@inchikey` — catching transcription
    # errors that composition checks cannot (wrong connectivity,
    # stereo, isotopes).
    #
    # Behaviour is engine-scaled, mirroring the resolver's opt-in
    # sources: with no engine configured the check emits one warning
    # explaining how to enable it (protection off is worth saying);
    # with an engine, mismatches are errors. Molecules without
    # identity annotations are never checked.
    class IdentityCrossCheck < Base
      register :identity_cross_check

      def run(formula)
        annotated = []
        walk(formula) do |node|
          next unless node.is_a?(AsciiChem::Model::Molecule)

          annotated << node if identity_annotations?(node)
        end
        return [] if annotated.empty?

        engine = AsciiChem::Inchi.engine
        return [warning(skip_message(annotated.length))] if engine.nil?

        annotated.flat_map { |molecule| cross_check(molecule, engine) }
      rescue AsciiChem::EngineMissingError => e
        [warning(e.message)]
      end

      private

      def identity_annotations?(molecule)
        molecule.identifiers.any? { |i| %w[inchi inchikey].include?(i.convention.to_s) }
      end

      def cross_check(molecule, engine)
        identity = engine.identity(molecule)
        molecule.identifiers.filter_map do |i|
          diagnostic_for(i, identity, molecule)
        end
      rescue AsciiChem::Error => e
        # Not derivable (e.g. a formula is not a structure: no bonds)
        # or the engine rejected it — report, never raise: the linter
        # stays total.
        [warning("cannot derive InChI for cross-check: #{e.message}", node: molecule)]
      end

      def diagnostic_for(identifier, identity, molecule)
        case identifier.convention.to_s
        when 'inchi'
          return nil if identifier.value == identity.inchi

          error('InChI annotation does not match the drawn structure: ' \
                "annotated #{identifier.value}, computed #{identity.inchi}",
                node: molecule)
        when 'inchikey'
          return nil if identifier.value == identity.inchikey

          error('InChIKey annotation does not match the drawn structure: ' \
                "annotated #{identifier.value}, computed #{identity.inchikey}",
                node: molecule)
        end
      end

      def skip_message(count)
        "structural identity cross-check skipped for #{count} annotated molecule(s): " \
          "no InChI engine configured — #{AsciiChem::Inchi::INSTALL_GUIDE}"
      end
    end
  end
end
