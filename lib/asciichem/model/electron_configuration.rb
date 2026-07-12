# frozen_string_literal: true

module AsciiChem
  module Model
    # Orbital occupancy: `1s^2 2s^2 2p^6`. Each entry is `[orbital,
    # occupancy]` where orbital is the string label (`"1s"`, `"2p"`) and
    # occupancy is the electron count as a string.
    #
    # Term symbols (^{multiplicity}L_J) live on the optional
    # `term_symbol` field.
    class ElectronConfiguration < Node
      TermSymbol = Struct.new(:multiplicity, :letter, :j_value, keyword_init: true) do
        def to_s
          "^#{multiplicity}#{letter}_#{j_value}"
        end
      end

      attr_accessor :orbitals, :term_symbol

      def initialize(orbitals:, term_symbol: nil)
        @orbitals = orbitals
        @term_symbol = term_symbol
      end

      def value_attributes
        { orbitals: orbitals, term_symbol: term_symbol }
      end

      def to_s
        parts = orbitals.map { |o, n| "#{o}^#{n}" }
        parts << term_symbol.to_s if term_symbol
        "ElectronConfig(#{parts.join(' ')})"
      end
    end
  end
end
