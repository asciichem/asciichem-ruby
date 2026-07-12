# frozen_string_literal: true

require "spec_helper"

RSpec.describe "embedded Plurimath math" do
  it "parses a backtick-delimited math run as EmbeddedMath" do
    formula = AsciiChem.parse("`x^2 + y^2`")
    node = formula.nodes.first
    expect(node).to be_a(AsciiChem::Model::EmbeddedMath)
  end

  it "wraps a real Plurimath formula" do
    formula = AsciiChem.parse("`x + 1`")
    embedded = formula.nodes.first
    expect(embedded.formula).to be_a(Plurimath::Math::Formula)
  end

  it "preserves the source string for round-trip" do
    source = "`K_c = [P]/[R]`"
    formula = AsciiChem.parse(source)
    expect(formula.to_text).to eq(source)
  end

  it "emits the Plurimath MathML in the embedded position" do
    formula = AsciiChem.parse("`x^2`")
    mathml = formula.to_mathml
    expect(mathml).to include("<math")
    # Plurimath's msup for x^2 — at minimum the x and the 2 should appear.
    expect(mathml).to include("<mi>x</mi>")
    expect(mathml).to include("<mn>2</mn>")
  end
end
