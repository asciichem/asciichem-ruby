# frozen_string_literal: true

require "spec_helper"

RSpec.describe "the adduct" do
  # Grammar v0.9.0 (asciichem-ruby#202): mhchem's middle-dot
  # connective at the formula level. The ASCII spelling is the period
  # with whitespace on both sides (or the literal middle dot); the
  # UNspaced period stays radical-suffix territory.

  describe "parsing" do
    it "builds an Adduct of molecules" do
      adduct = AsciiChem.parse("CuSO4 . 5H2O").nodes.first
      expect(adduct).to be_a(AsciiChem::Model::Adduct)
      expect(adduct.components.length).to eq(2)
      expect(adduct.components.last.coefficient).to eq("5")
    end

    it "accepts the literal middle dot as the mhchem alias" do
      expect(AsciiChem.parse("CuSO4 · 5H2O").to_text).to eq("CuSO4 . 5H_2O")
    end

    it "parses n-ary chains" do
      adduct = AsciiChem.parse("NaCl . KCl . CaCl2").nodes.first
      expect(adduct.components.length).to eq(3)
    end

    it "keeps the unspaced period as radical electrons" do
      molecule = AsciiChem.parse("Cl.Fe").nodes.first
      expect(molecule).to be_a(AsciiChem::Model::Molecule)
      expect(molecule.nodes.first.radical_electrons).to eq(1)
    end
  end

  describe "text round-trip" do
    it "round-trips the ASCII form" do
      expect(AsciiChem.parse("CuSO4 . 5H2O").to_text).to eq("CuSO4 . 5H_2O")
    end

    it "round-trips n-ary chains" do
      expect(AsciiChem.parse("NaCl . KCl . CaCl2").to_text).to eq("NaCl . KCl . CaCl2")
    end
  end

  describe "renderers" do
    let(:adduct) { AsciiChem.parse("CuSO4 . 5H2O") }

    it "typesets the middle dot in MathML" do
      expect(adduct.to_mathml).to include("·")
    end

    it "emits mhchem's own connective in LaTeX" do
      expect(adduct.to_latex).to include("\\cdot")
    end

    it "emits the HTML entity" do
      expect(adduct.to_html).to include("&middot;")
    end

    it "emits the unicode dot in linear SVG" do
      expect(adduct.to_svg).to include("·")
    end
  end

  describe "equality" do
    it "treats adducts differing in components as distinct" do
      a = AsciiChem.parse("CuSO4 . 5H2O").nodes.first
      b = AsciiChem.parse("CuSO4 . 5H2O").nodes.first
      expect(a).to eq(b)
      expect(a).not_to eq(AsciiChem.parse("CuSO4").nodes.first)
    end
  end

  describe "the wire form" do
    it "round-trips through the model JSON" do
      back = AsciiChem.from_model_json(AsciiChem.parse("CuSO4 . 5H2O").to_model_json)
      expect(back.nodes.first).to be_a(AsciiChem::Model::Adduct)
      expect(back.to_text).to eq("CuSO4 . 5H_2O")
    end
  end

  describe "CML round-trip" do
    it "rides the aci: text channel and re-parses" do
      cml = AsciiChem.parse("CuSO4 . 5H2O").to_cml
      expect(cml).to include("<aci:adduct")

      back = AsciiChem::Cml.parse(cml)
      expect(back.to_text).to eq("CuSO4 . 5H_2O")
    end
  end
end
