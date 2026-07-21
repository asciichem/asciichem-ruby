# frozen_string_literal: true

require "spec_helper"

# Round-trip conformance: AsciiChem.parse(s).to_text == s for any
# canonical input. The Text formatter is the canonicaliser — equivalent
# inputs map to the same output, and canonical inputs round-trip
# exactly.
RSpec.describe AsciiChem::Formatter::Text do
  cases = [
    # atoms
    "H",
    "He",
    "C",
    # subscripts
    "H_2",
    "H_2O",
    "Ca(OH)_2",
    "H_2SO_4",
    # isotopes — the headline semantic fix
    "^14C",
    "^131I",
    # charges
    "Ca^2+",
    "Cl^-",
    "SO_4^2-",
    # stoichiometric coefficients
    "2H_2O",
    "3H_2",
    # bonds — linear structural notation
    "H-O-H",
    "H_2C=CH_2",
    "HC#CH",
    # reactions
    "2H_2 + O_2 -> 2H_2O",
    "N_2 + 3H_2 <=>[Fe][400°C] 2NH_3",
    "A + B <-> C"
  ]

  cases.each do |input|
    it "round-trips #{input.inspect}" do
      rendered = AsciiChem.parse(input).to_text
      expect(rendered).to eq(input)
    end
  end

  describe "canonicalisation" do
    it "normalises +2 charge to 2+ (IUPAC number-then-sign)" do
      atom = AsciiChem.parse("Ca^+2").nodes.first.nodes.first
      expect(atom.charge).to eq("2+")
    end

    it "accepts implicit subscript on hydrogen (H2 -> H_2)" do
      # Hydrogen is the special case: H cannot form ring closures
      # (only 1 bond), so bare digits after H are unambiguously
      # subscripts. Lets users write H2O, CH4, NH3 without `_`.
      # Ring closures on other elements (`C1-C-C1` is cyclohexane)
      # remain unchanged.
      expect(AsciiChem.parse("H2").to_text).to eq("H_2")
      expect(AsciiChem.parse("H2O").to_text).to eq("H_2O")
      expect(AsciiChem.parse("CH4").to_text).to eq("CH_4")
      expect(AsciiChem.parse("NH3").to_text).to eq("NH_3")
    end
  end
end
