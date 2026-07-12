# frozen_string_literal: true

require "spec_helper"

# End-to-end: real-world formulae from chemistry references. The point
# is to ensure the parser handles realistic inputs without falling over,
# not to assert exact model shapes.
RSpec.describe "end-to-end parse" do
  samples = [
    "H_2O",                # water
    "CO_2",                # carbon dioxide
    "NaCl",                # sodium chloride
    "C_6H_12O_6",          # glucose
    "Ca(OH)_2",            # calcium hydroxide
    "H_2SO_4",             # sulfuric acid
    "(NH_4)_2SO_4",        # ammonium sulfate
    "^14C",                # carbon-14
    "^238U",               # uranium-238
    "Ca^2+",               # calcium ion
    "SO_4^2-",             # sulfate ion
    "Fe^2+",               # iron(II)
    "Fe^3+",               # iron(III)
    "2H_2 + O_2 -> 2H_2O", # combustion
    "N_2 + 3H_2 <=>[Fe][400°C] 2NH_3", # Haber process
    "HCl + NaOH -> NaCl + H_2O",       # neutralisation
    "CH_4 + 2O_2 -> CO_2 + 2H_2O"      # methane combustion
  ]

  samples.each do |sample|
    it "parses #{sample.inspect} without error" do
      expect { AsciiChem.parse(sample) }.not_to raise_error
    end

    it "produces MathML for #{sample.inspect}" do
      xml = AsciiChem.parse(sample).to_mathml
      expect(xml).to include("<math")
      expect(xml).to include("</math>")
    end

    it "round-trips #{sample.inspect}" do
      formula = AsciiChem.parse(sample)
      expect(formula.to_text).to eq(sample)
    end
  end
end
