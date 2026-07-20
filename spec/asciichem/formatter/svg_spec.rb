# frozen_string_literal: true

require "spec_helper"

RSpec.describe AsciiChem::Formatter::Svg do
  def render(source)
    AsciiChem.parse(source).to_svg
  end

  it "emits a well-formed SVG document" do
    svg = render("H_2O")
    expect(svg).to start_with("<?xml")
    expect(svg).to include("<svg")
    expect(svg).to include("</svg>")
  end

  it "includes the formula text in a <text> element" do
    svg = render("H_2O")
    expect(svg).to include("<text")
    expect(svg).to include("H_2O")
  end

  it "scales width with formula length" do
    short = render("H").lines.find { |l| l.include?("<svg") }
    long = render("H_2SO_4").lines.find { |l| l.include?("<svg") }
    expect(long).to match(/width="(\d+)"/)
    expect(short.to_s).to match(/width="(\d+)"/)
  end

  describe "beyond-formulas constructs" do
    it "renders a Crystal without raising" do
      expect { render("crystal[NaCl](a=5.64,sg=Fm-3m){Na@f(0,0,0)}") }
        .not_to raise_error
    end

    it "renders a Spectrum without raising" do
      expect { render(%(spectrum[nmr](type=1H){1.2: 3H s "CH3"})) }
        .not_to raise_error
    end

    it "renders a Calculation without raising" do
      expect { render("calc(b3lyp){energy: -234.5}") }.not_to raise_error
    end

    it "renders a ZMatrix without raising" do
      expect { render("zmatrix{\n  C1\n  H2 C1 1.09\n}") }.not_to raise_error
    end

    it "renders a Mechanism without raising" do
      expect { render("mechanism{\n  step1: A -> B\n}") }.not_to raise_error
    end

    it "includes the construct text in the SVG output" do
      svg = render("crystal[NaCl](a=5.64,sg=Fm-3m){Na@f(0,0,0)}")
      expect(svg).to include("crystal")
      expect(svg).to include("NaCl")
    end
  end
end
