# frozen_string_literal: true

require "spec_helper"

RSpec.describe AsciiChem::Formatter::Latex do
  def render(source)
    AsciiChem.parse(source).to_latex
  end

  it "wraps molecules in \\ce{}" do
    expect(render("H_2O")).to eq("\\ce{H2O}")
  end

  it "uses bare digits for multi-digit values" do
    expect(render("^14C")).to eq("\\ce{^14C}")
  end

  it "uses braces for non-digit superscripts" do
    expect(render("Ca^2+")).to eq("\\ce{Ca^{2+}}")
  end

  it "renders stoichiometric coefficients" do
    expect(render("2H_2O")).to eq("\\ce{2H2O}")
  end

  it "renders groups with multiplicity" do
    expect(render("Ca(OH)_2")).to eq("\\ce{Ca(OH)2}")
  end

  it "renders reactions inside a single \\ce{} block" do
    expect(render("2H_2 + O_2 -> 2H_2O")).to eq("\\ce{2H2 + O2 -> 2H2O}")
  end

  it "renders equilibrium with conditions" do
    expect(render("N_2 + 3H_2 <=>[Fe][400°C] 2NH_3")).to eq("\\ce{N2 + 3H2 <=>[Fe][400°C] 2NH3}")
  end

  it "renders single bonds" do
    expect(render("H-O-H")).to eq("\\ce{H-O-H}")
  end

  it "renders double and triple bonds as mhchem bond macros" do
    expect(render("C=C")).to eq("\\ce{C=C}")
    expect(render("HC#CH")).to eq("\\ce{HC\\equiv{}CH}")
  end
end

RSpec.describe "donation-arrow LaTeX" do
  it "spells the decorated arrows verbatim" do
    expect(AsciiChem.parse("A <=>+ B").to_latex).to include("<=>+")
    expect(AsciiChem.parse("A <=>- B").to_latex).to include("<=>-")
  end
end
