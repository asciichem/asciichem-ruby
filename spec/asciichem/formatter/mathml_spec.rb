# frozen_string_literal: true

require "spec_helper"

RSpec.describe AsciiChem::Formatter::Mathml do
  subject(:formatter) { described_class.new }

  def render(source)
    AsciiChem.parse(source).to_mathml
  end

  it "wraps every output in a <math> element" do
    expect(render("H")).to include("<math")
    expect(render("H")).to include("</math>")
  end

  describe "atom rendering" do
    it "emits <mi> for a bare element" do
      xml = render("He")
      expect(xml).to include("<mi>He</mi>")
    end

    it "binds subscript directly to the atom via <msub>" do
      xml = render("H_2")
      expect(xml).to include("<msub>")
      expect(xml).to include("<mi>H</mi>")
      expect(xml).to include("<mn>2</mn>")
    end

    it "binds a prefix isotope to the atom via <msup> — the semantic fix" do
      xml = render("^14C")
      # The fix: <msup><mi>C</mi><mn>14</mn></msup>, NOT
      # <msup><mi></mi><mn>14</mn></msup><mi>C</mi>.
      expect(xml).to include("<msup>")
      expect(xml).to include("<mi>C</mi>")
      expect(xml).to include("<mn>14</mn>")
      expect(xml).not_to match(%r{<mi>\s*</mi>})
    end

    it "renders a suffix charge as an <msup> with number + sign" do
      xml = render("Ca^2+")
      expect(xml).to include("<msup>")
      expect(xml).to include("<mi>Ca</mi>")
      expect(xml).to include("<mn>2</mn>")
      expect(xml).to include("<mo>+</mo>")
    end
  end

  describe "molecule rendering" do
    it "places the coefficient before the atoms" do
      xml = render("2H_2O")
      # The 2 coefficient should appear before the H.
      expect(xml.index(%r{<mn>2</mn>}) < xml.index("<mi>H</mi>")).to be(true)
    end
  end

  describe "group rendering" do
    it "emits bracket operators around the inner content" do
      xml = render("(OH)_2")
      expect(xml).to include("<mo>(</mo>")
      expect(xml).to include("<mo>)</mo>")
      expect(xml).to include("<msub>") # multiplicity wrap
    end
  end

  describe "reaction rendering" do
    it "emits the arrow entity between reactants and products" do
      xml = render("H_2 + O_2 -> H_2O")
      expect(xml).to include("→")
    end

    it "renders equilibrium conditions above/below the arrow" do
      xml = render("N_2 + 3H_2 <=>[Fe][400°C] 2NH_3")
      expect(xml).to include("⇌")
      expect(xml).to include("Fe")
      expect(xml).to include("400°C")
      expect(xml).to include("munderover")
    end
  end
end
