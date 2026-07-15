# frozen_string_literal: true

module AsciiChem
  # Periodic table as a single source of truth for element data.
  # Used by linter checks (element validation, isotope sanity, valence)
  # and any future code that needs chemically-grounded defaults.
  #
  # Adding a new field (e.g. covalent radius for layout, common
  # oxidation states for redox checks) means adding one column to
  # `Element` and populating it across `ELEMENTS` — no other code
  # changes.
  module PeriodicTable
    Element = Struct.new(:symbol, :atomic_number, :max_valence, keyword_init: true)

    # Subset covering the elements chemistry most commonly deals with.
    # Each entry: symbol => Element. Adding more elements is one
    # line per element; the linter picks them up automatically.
    ELEMENTS = {
      # Period 1
      "H"  => Element.new(symbol: "H",  atomic_number: 1,  max_valence: 1),
      "He" => Element.new(symbol: "He", atomic_number: 2,  max_valence: 0),
      # Period 2
      "Li" => Element.new(symbol: "Li", atomic_number: 3,  max_valence: 1),
      "Be" => Element.new(symbol: "Be", atomic_number: 4,  max_valence: 2),
      "B"  => Element.new(symbol: "B",  atomic_number: 5,  max_valence: 3),
      "C"  => Element.new(symbol: "C",  atomic_number: 6,  max_valence: 4),
      "N"  => Element.new(symbol: "N",  atomic_number: 7,  max_valence: 3),
      "O"  => Element.new(symbol: "O",  atomic_number: 8,  max_valence: 2),
      "F"  => Element.new(symbol: "F",  atomic_number: 9,  max_valence: 1),
      "Ne" => Element.new(symbol: "Ne", atomic_number: 10, max_valence: 0),
      # Period 3
      "Na" => Element.new(symbol: "Na", atomic_number: 11, max_valence: 1),
      "Mg" => Element.new(symbol: "Mg", atomic_number: 12, max_valence: 2),
      "Al" => Element.new(symbol: "Al", atomic_number: 13, max_valence: 3),
      "Si" => Element.new(symbol: "Si", atomic_number: 14, max_valence: 4),
      "P"  => Element.new(symbol: "P",  atomic_number: 15, max_valence: 5),
      "S"  => Element.new(symbol: "S",  atomic_number: 16, max_valence: 6),
      "Cl" => Element.new(symbol: "Cl", atomic_number: 17, max_valence: 1),
      "Ar" => Element.new(symbol: "Ar", atomic_number: 18, max_valence: 0),
      # Period 4 (common)
      "K"  => Element.new(symbol: "K",  atomic_number: 19, max_valence: 1),
      "Ca" => Element.new(symbol: "Ca", atomic_number: 20, max_valence: 2),
      "Sc" => Element.new(symbol: "Sc", atomic_number: 21, max_valence: 3),
      "Ti" => Element.new(symbol: "Ti", atomic_number: 22, max_valence: 4),
      "V"  => Element.new(symbol: "V",  atomic_number: 23, max_valence: 5),
      "Cr" => Element.new(symbol: "Cr", atomic_number: 24, max_valence: 6),
      "Mn" => Element.new(symbol: "Mn", atomic_number: 25, max_valence: 7),
      "Fe" => Element.new(symbol: "Fe", atomic_number: 26, max_valence: 6),
      "Co" => Element.new(symbol: "Co", atomic_number: 27, max_valence: 4),
      "Ni" => Element.new(symbol: "Ni", atomic_number: 28, max_valence: 4),
      "Cu" => Element.new(symbol: "Cu", atomic_number: 29, max_valence: 4),
      "Zn" => Element.new(symbol: "Zn", atomic_number: 30, max_valence: 2),
      "Ga" => Element.new(symbol: "Ga", atomic_number: 31, max_valence: 3),
      "Ge" => Element.new(symbol: "Ge", atomic_number: 32, max_valence: 4),
      "As" => Element.new(symbol: "As", atomic_number: 33, max_valence: 3),
      "Se" => Element.new(symbol: "Se", atomic_number: 34, max_valence: 2),
      "Br" => Element.new(symbol: "Br", atomic_number: 35, max_valence: 1),
      "Kr" => Element.new(symbol: "Kr", atomic_number: 36, max_valence: 0),
      # Period 5 (common)
      "Rb" => Element.new(symbol: "Rb", atomic_number: 37, max_valence: 1),
      "Sr" => Element.new(symbol: "Sr", atomic_number: 38, max_valence: 2),
      "Y"  => Element.new(symbol: "Y",  atomic_number: 39, max_valence: 3),
      "Zr" => Element.new(symbol: "Zr", atomic_number: 40, max_valence: 4),
      "Nb" => Element.new(symbol: "Nb", atomic_number: 41, max_valence: 5),
      "Mo" => Element.new(symbol: "Mo", atomic_number: 42, max_valence: 6),
      "Tc" => Element.new(symbol: "Tc", atomic_number: 43, max_valence: 6),
      "Ru" => Element.new(symbol: "Ru", atomic_number: 44, max_valence: 6),
      "Rh" => Element.new(symbol: "Rh", atomic_number: 45, max_valence: 6),
      "Pd" => Element.new(symbol: "Pd", atomic_number: 46, max_valence: 4),
      "Ag" => Element.new(symbol: "Ag", atomic_number: 47, max_valence: 4),
      "Cd" => Element.new(symbol: "Cd", atomic_number: 48, max_valence: 2),
      "In" => Element.new(symbol: "In", atomic_number: 49, max_valence: 3),
      "Sn" => Element.new(symbol: "Sn", atomic_number: 50, max_valence: 4),
      "Sb" => Element.new(symbol: "Sb", atomic_number: 51, max_valence: 3),
      "Te" => Element.new(symbol: "Te", atomic_number: 52, max_valence: 2),
      "I"  => Element.new(symbol: "I",  atomic_number: 53, max_valence: 1),
      "Xe" => Element.new(symbol: "Xe", atomic_number: 54, max_valence: 0),
      # Period 6 (common)
      "Cs" => Element.new(symbol: "Cs", atomic_number: 55, max_valence: 1),
      "Ba" => Element.new(symbol: "Ba", atomic_number: 56, max_valence: 2),
      "W"  => Element.new(symbol: "W",  atomic_number: 74, max_valence: 6),
      "Pt" => Element.new(symbol: "Pt", atomic_number: 78, max_valence: 4),
      "Au" => Element.new(symbol: "Au", atomic_number: 79, max_valence: 6),
      "Hg" => Element.new(symbol: "Hg", atomic_number: 80, max_valence: 2),
      "Tl" => Element.new(symbol: "Tl", atomic_number: 81, max_valence: 3),
      "Pb" => Element.new(symbol: "Pb", atomic_number: 82, max_valence: 4),
      "Bi" => Element.new(symbol: "Bi", atomic_number: 83, max_valence: 3),
      # Period 7 (common)
      "U"  => Element.new(symbol: "U",  atomic_number: 92, max_valence: 6)
    }.freeze

    def self.element(symbol)
      ELEMENTS[symbol.to_s]
    end

    def self.known?(symbol)
      ELEMENTS.key?(symbol.to_s)
    end

    def self.atomic_number(symbol)
      element(symbol.to_s)&.atomic_number
    end

    def self.max_valence(symbol)
      element(symbol.to_s)&.max_valence
    end

    def self.symbols
      ELEMENTS.keys
    end
  end
end
