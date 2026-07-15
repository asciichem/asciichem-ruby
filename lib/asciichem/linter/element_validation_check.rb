# frozen_string_literal: true

module AsciiChem
  module Linter
    # Validates that each Atom's element symbol is in the periodic
    # table. Catches typos like `Hx`, `Cy`, `Oq` that would otherwise
    # silently parse and produce nonsense output. Uses
    # `AsciiChem::PeriodicTable` as the single source of truth.
    #
    # Severity is `warning`, not `error` — the parser is total and
    # might intentionally accept placeholder elements (e.g. `X` for
    # "unknown halogen" in teaching contexts). The linter flags them
    # for the user to confirm.
    class ElementValidationCheck < Base
      register :element_validation

      def run(formula)
        diagnostics = []
        walk(formula) do |node|
          next unless node.is_a?(AsciiChem::Model::Atom)

          check_atom(node, diagnostics)
        end
        diagnostics
      end

      private

      def check_atom(atom, diagnostics)
        return if AsciiChem::PeriodicTable.known?(atom.element)

        diagnostics << warning(
          "Unknown element symbol #{atom.element.inspect}; not in the periodic table",
          node: atom
        )
      end
    end
  end
end
