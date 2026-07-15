# frozen_string_literal: true

require "spec_helper"

RSpec.describe AsciiChem::Formatter::StructuralSvg do
  let(:formatter) { described_class.new }

  def render(formula)
    formatter.render(formula)
  end

  def parse_render(source)
    render(AsciiChem.parse(source))
  end

  describe "well-formedness" do
    it "emits a well-formed SVG root" do
      xml = parse_render("H-O-H")
      expect(xml).to start_with(%(<?xml version="1.0"?>\n))
      expect(xml).to include("<svg")
      expect(xml).to include("</svg>")
    end

    it "declares the SVG namespace" do
      xml = parse_render("H-O-H")
      expect(xml).to include('xmlns="http://www.w3.org/2000/svg"')
    end

    it "includes a role attribute for accessibility" do
      xml = parse_render("H-O-H")
      expect(xml).to include('role="img"')
    end

    it "includes a <title> for screen readers" do
      xml = parse_render("H-O-H")
      expect(xml).to include("<title>")
      expect(xml).to include("</title>")
    end
  end

  describe "atoms" do
    it "draws one circle per atom" do
      xml = parse_render("H-O-H")
      expect(xml.scan(/<circle\b/).length).to eq(3)
    end

    it "labels each circle with its element symbol" do
      xml = parse_render("H-O-H")
      # 3 atoms: H, O, H — one <text> per element.
      h_labels = xml.scan(%r{<text[^>]*>H</text>}).length
      o_labels = xml.scan(%r{<text[^>]*>O</text>}).length
      expect(h_labels).to eq(2)
      expect(o_labels).to eq(1)
    end

    it "falls back to the linear Svg formatter when there are no bonds" do
      # H_2O is a formula, not a structural chain — no bonds.
      linear = AsciiChem::Formatter::Svg.new.render(AsciiChem.parse("H_2O"))
      expect(parse_render("H_2O")).to eq(linear)
    end

    it "falls back to the linear Svg formatter when the input is a reaction" do
      linear = AsciiChem::Formatter::Svg.new.render(AsciiChem.parse("H_2 + O_2 -> H_2O"))
      expect(parse_render("H_2 + O_2 -> H_2O")).to eq(linear)
    end
  end

  describe "bonds" do
    it "draws a single line for a single bond" do
      xml = parse_render("H-O-H")
      # 3 atoms, 2 single bonds. We should see at least 2 <line>
      # elements (and no <polygon> or other bond-shape elements).
      expect(xml.scan(/<line\b/).length).to be >= 2
    end

    it "draws three parallel lines for a triple bond" do
      xml = parse_render("HC#CH")
      # Triple bond: 3 parallel <line>s between the two carbons,
      # plus any bonds from H to C (none here since H is implicit in
      # subscript-free form, but H is its own atom in our parse).
      # Expect at least 3 <line>s.
      expect(xml.scan(/<line\b/).length).to be >= 3
    end

    it "draws a filled polygon for a wedge bond" do
      xml = parse_render("C>-C")
      expect(xml).to include("<polygon")
    end

    it "draws perpendicular lines for a hash bond" do
      xml = parse_render("C-<C")
      expect(xml.scan(/<line\b/).length).to be >= 5
    end
  end

  describe "deterministic output" do
    it "produces byte-equal output across runs of the same input" do
      out1 = parse_render("H_2C=CH_2")
      out2 = parse_render("H_2C=CH_2")
      expect(out1).to eq(out2)
    end
  end
end
