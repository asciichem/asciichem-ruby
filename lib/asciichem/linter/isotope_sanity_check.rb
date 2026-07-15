# frozen_string_literal: true

module AsciiChem
  module Linter
    # Sanity-checks isotope mass numbers against the element's atomic
    # number. The isotope's mass must be ≥ the atomic number (a nucleus
    # can't have fewer protons than its mass number suggests).
    #
    # Atomic-number table is limited to common elements; unknown
    # elements produce an info diagnostic, not an error.
    class IsotopeSanityCheck < Base
      register :isotope_sanity

      def run(formula)
        diagnostics = []
        walk(formula) do |node|
          next unless node.is_a?(AsciiChem::Model::Atom)
          next unless node.isotope

          check_atom(node, diagnostics)
        end
        diagnostics
      end

      private

      def check_atom(atom, diagnostics)
        z = AsciiChem::PeriodicTable.atomic_number(atom.element)
        if z.nil?
          diagnostics << info(
            "Element #{atom.element.inspect} not in periodic table; skipping isotope check",
            node: atom
          )
          return
        end

        mass = atom.isotope.to_i
        return if mass >= z

        diagnostics << error(
          "Isotope mass #{mass} is less than atomic number #{z} for #{atom.element}",
          node: atom
        )
      end
    end
  end
end
