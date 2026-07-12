# frozen_string_literal: true

require "spec_helper"

RSpec.describe AsciiChem::Formatter::Html do
  def render(source)
    AsciiChem.parse(source).to_html
  end

  it "renders subscripts as <sub>" do
    expect(render("H_2O")).to eq("H<sub>2</sub>O")
  end

  it "renders isotopes as prefix <sup>" do
    expect(render("^14C")).to eq("<sup>14</sup>C")
  end

  it "renders charges as <sup>" do
    expect(render("Ca^2+")).to eq("Ca<sup>2+</sup>")
  end

  it "renders coefficients inline" do
    expect(render("2H_2O")).to eq("2H<sub>2</sub>O")
  end

  it "renders reactions with the unicode arrow" do
    expect(render("2H_2 + O_2 -> 2H_2O")).to eq("2H<sub>2</sub> + O<sub>2</sub> → 2H<sub>2</sub>O")
  end

  it "renders equilibrium conditions as sup/sub on the arrow" do
    out = render("N_2 + 3H_2 <=>[Fe][400°C] 2NH_3")
    expect(out).to include("<sup>Fe</sup>⇌<sub>400°C</sub>")
  end

  it "escapes HTML-significant characters in text" do
    expect(render("a<b")).to include("&lt;")
  end
end
