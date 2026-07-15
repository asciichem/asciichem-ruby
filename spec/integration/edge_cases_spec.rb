# frozen_string_literal: true

require "spec_helper"

RSpec.describe "AsciiChem edge cases" do
  describe "parser robustness" do
    [
      "",
      "   ",
      "@@@",
      "12345",
      "->",
      "+",
      "<=>",
      "()",
      "[]",
      "{}",
      "^",
      "_",
      "H^",
      "H_"
    ].each do |input|
      it "raises ParseError cleanly for #{input.inspect}" do
        expect { AsciiChem.parse(input) }.to raise_error(AsciiChem::ParseError)
      end
    end
  end

  describe "parser acceptance" do
    [
      "H",
      "He",
      "H_2O",
      "^14C",
      "Ca^2+",
      "Ca^(II)",
      "Cl^-",
      "(OH)_2",
      "((OH)_2)",
      "[OH]_2",
      "{OH}_2",
      "H-O-H",
      "HC#CH",
      "H_2C=CH_2",
      "2H_2 + O_2 -> 2H_2O",
      "N_2 + 3H_2 <=>[Fe][400°C] 2NH_3",
      "A -> B -> C",
      "1s^2 2s^2",
      "1s^2 2s^2 2p^6 3d^10 4s^2",
      "`K_c = 1`",
      '"free text"',
      'H_2O "at room temp"',
      "::O",
      "N.",
      ":N.",
      "Fe^(II) 1s^2 2s^2"
    ].each do |input|
      it "accepts #{input.inspect}" do
        expect { AsciiChem.parse(input) }.not_to raise_error
      end
    end
  end

  describe "text round-trip conformance" do
    [
      "H",
      "He",
      "H_2O",
      "^14C",
      "Ca^2+",
      "Cl^-",
      "(OH)_2",
      "[OH]_2",
      "{OH}_2",
      "H-O-H",
      "HC#CH",
      "H_2C=CH_2",
      "2H_2 + O_2 -> 2H_2O",
      "1s^2 2s^2 2p^6 3d^10 4s^2",
      '"free text"',
      "::O",
      "N.",
      ":N."
    ].each do |source|
      it "round-trips #{source.inspect} via Text formatter" do
        expect(AsciiChem.parse(source).to_text).to eq(source)
      end
    end
  end

  describe "CML round-trip conformance" do
    [
      "H_2O",
      "^14C",
      "Ca^2+",
      "2H_2 + O_2 -> 2H_2O",
      "CH_3-CH_2-OH",
      "H-O-H",
      "Fe^(II)",
      "::O",
      "N.",
      "::N.",
      "1s^2 2s^2",
      "1s^2 2s^2 2p^6 3d^10 4s^2",
      "`K_c = [P]/[R]`",
      '"note: toxic"',
      "(OH)_2",
      "(H_2O)_3",
      "Ca(OH)_2",
      "[OH]_2",
      "{OH}_2",
      "((OH))",
      "((OH)_2)",
      "Ca((OH)_2)",
      "`a < b && c > d`"
    ].each do |source|
      it "round-trips #{source.inspect} via CML" do
        round_trip = AsciiChem::Cml.parse(AsciiChem.parse(source).to_cml).to_text
        expect(round_trip).to eq(source)
      end
    end
  end

  describe "deterministic output" do
    it "produces byte-equal CML across multiple runs" do
      source = "2H_2 + O_2 -> 2H_2O"
      xml1 = AsciiChem.parse(source).to_cml
      xml2 = AsciiChem.parse(source).to_cml
      expect(xml1).to eq(xml2)
    end

    it "produces byte-equal structural SVG across multiple runs" do
      source = "CH_3-CH_2-OH"
      svg1 = AsciiChem::Formatter[:structural_svg].new.render(AsciiChem.parse(source))
      svg2 = AsciiChem::Formatter[:structural_svg].new.render(AsciiChem.parse(source))
      expect(svg1).to eq(svg2)
    end

    it "produces byte-equal MathML across multiple runs" do
      source = "Ca^(II) 1s^2 2s^2"
      xml1 = AsciiChem.parse(source).to_mathml
      xml2 = AsciiChem.parse(source).to_mathml
      expect(xml1).to eq(xml2)
    end
  end

  describe "formatter registry" do
    it "resolves every shipped formatter by snake_case name" do
      expected = {
        mathml: AsciiChem::Formatter::Mathml,
        text: AsciiChem::Formatter::Text,
        html: AsciiChem::Formatter::Html,
        latex: AsciiChem::Formatter::Latex,
        svg: AsciiChem::Formatter::Svg,
        structural_svg: AsciiChem::Formatter::StructuralSvg
      }
      expected.each do |name, klass|
        expect(AsciiChem::Formatter[name]).to eq(klass), "#{name} should resolve"
      end
    end
  end

  describe "linter coverage" do
    it "registers all six built-in checks" do
      expect(AsciiChem::Linter::Registry.names).to contain_exactly(
        :balance,
        :bracket_balance,
        :element_validation,
        :isotope_sanity,
        :unclosed_ring,
        :valence
      )
    end

    it "returns no errors for clean water" do
      diagnostics = AsciiChem::Linter.run(AsciiChem.parse("H_2O"))
      expect(diagnostics.select { |d| d.severity == :error }).to be_empty
    end
  end

  describe "periodic table coverage" do
    it "has at least 60 elements registered" do
      expect(AsciiChem::PeriodicTable.symbols.length).to be >= 60
    end

    it "includes all elements commonly used in organic chemistry" do
      %w[H C N O F P S Cl Br I B Si].each do |symbol|
        expect(AsciiChem::PeriodicTable.known?(symbol)).to be(true), "#{symbol} should be known"
      end
    end
  end
end
