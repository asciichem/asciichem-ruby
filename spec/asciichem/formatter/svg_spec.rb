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
end
