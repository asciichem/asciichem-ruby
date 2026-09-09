# frozen_string_literal: true

module AsciiChem
  module Linter
    # Validates the *format* of molecule identifier annotations
    # (`@cas("...")`, `@inchi("...")`, `@smiles("...")`) whose
    # convention has a registered offline validator
    # (AsciiChem::Identifiers). Lexical/checksum only — checking that
    # an identifier is actually *assigned* to a substance is
    # resolution (TODO.v2 07 Layer 2), not linting. Conventions
    # without a validator (e.g. `iupac`, `cid`) are skipped silently.
    class IdentifierFormatCheck < Base
      register :identifier_format

      def run(formula)
        diagnostics = []
        walk(formula) do |node|
          next unless node.is_a?(AsciiChem::Model::Molecule)

          node.identifiers.each do |identifier|
            message = format_message(identifier)
            next if message.nil?

            diagnostics << error(
              "#{message} (#{identifier.convention} identifier on #{label_for(node)})",
              node: node
            )
          end
        end
        diagnostics
      end

      private

      def format_message(identifier)
        convention = identifier.convention.to_s
        return nil unless AsciiChem::Identifiers.known?(convention)

        AsciiChem::Identifiers.diagnostic(convention, identifier.value)
      end

      def label_for(molecule)
        formula = molecule.hill_formula
        formula.empty? ? "molecule" : formula
      end
    end
  end
end
