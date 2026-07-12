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

      ATOMIC_NUMBERS = {
        "H"  => 1, "He" => 2,
        "Li" => 3, "Be" => 4, "B" => 5, "C" => 6, "N" => 7, "O" => 8, "F" => 9, "Ne" => 10,
        "Na" => 11, "Mg" => 12, "Al" => 13, "Si" => 14, "P" => 15, "S" => 16, "Cl" => 17, "Ar" => 18,
        "K"  => 19, "Ca" => 20,
        "Fe" => 26, "Cu" => 29, "Zn" => 30,
        "Br" => 35,
        "Ag" => 47, "I"  => 53,
        "Au" => 79, "Hg" => 80,
        "Pb" => 82, "U"  => 92
      }.freeze

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
        z = ATOMIC_NUMBERS[atom.element]
        if z.nil?
          diagnostics << info(
            "Element #{atom.element.inspect} not in isotope table; skipping isotope check",
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
