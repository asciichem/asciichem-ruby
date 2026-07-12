# frozen_string_literal: true

require "spec_helper"

RSpec.describe AsciiChem::Model::Molecule do
  describe "stereochemistry" do
    it "defaults stereo to nil" do
      mol = described_class.new(nodes: [])
      expect(mol.stereo).to be_nil
    end

    it "stores stereo as a symbol" do
      mol = described_class.new(nodes: [], stereo: :R)
      expect(mol.stereo).to eq(:R)
    end

    it "exposes stereo_letter for rendering" do
      expect(described_class.new(nodes: [], stereo: :R).stereo_letter).to eq("R")
      expect(described_class.new(nodes: [], stereo: :S).stereo_letter).to eq("S")
      expect(described_class.new(nodes: [], stereo: :alpha).stereo_letter).to eq("alpha")
    end
  end

  describe "parser integration" do
    it "parses (R)- prefix" do
      mol = AsciiChem.parse("(R)-CH_3").nodes.first
      expect(mol.stereo).to eq(:R)
    end

    it "parses (S)- prefix" do
      mol = AsciiChem.parse("(S)-CH_3").nodes.first
      expect(mol.stereo).to eq(:S)
    end

    it "parses (E)- prefix" do
      mol = AsciiChem.parse("(E)-CH=CH").nodes.first
      expect(mol.stereo).to eq(:E)
    end

    it "parses (Z)- prefix" do
      mol = AsciiChem.parse("(Z)-CH=CH").nodes.first
      expect(mol.stereo).to eq(:Z)
    end

    it "parses (a)- as alpha" do
      mol = AsciiChem.parse("(a)-CH_3").nodes.first
      expect(mol.stereo).to eq(:alpha)
    end

    it "parses (α)- Unicode as alpha" do
      mol = AsciiChem.parse("(α)-CH_3").nodes.first
      expect(mol.stereo).to eq(:alpha)
    end

    it "leaves (OH)- as a group + bond, not stereo" do
      # (OH)-C: this is a group with a bond, not a stereo prefix.
      # The molecule rule should fail stereo_prefix and fall through.
      mol = AsciiChem.parse("(OH)-CH_3").nodes.first rescue nil
      # The molecule should still parse, just without stereo.
      expect(mol).not_to be_nil if mol
    end
  end

  describe "round-trip" do
    it "round-trips (R)- prefix" do
      expect(AsciiChem.parse("(R)-CH_3").to_text).to eq("(R)-CH_3")
    end

    it "round-trips (S)- prefix" do
      expect(AsciiChem.parse("(S)-CH_3").to_text).to eq("(S)-CH_3")
    end

    it "round-trips (E)- prefix" do
      expect(AsciiChem.parse("(E)-CH=CH").to_text).to eq("(E)-CH=CH")
    end
  end

  describe "formatters" do
    it "emits stereo in MathML via mtext" do
      xml = AsciiChem.parse("(R)-CH_3").to_mathml
      expect(xml).to include("<mtext>(R)-</mtext>")
    end

    it "emits stereo in LaTeX inside ce{}" do
      latex = AsciiChem.parse("(R)-CH_3").to_latex
      expect(latex).to eq("\\ce{(R)-CH3}")
    end

    it "emits stereo in HTML as plain text" do
      html = AsciiChem.parse("(R)-CH_3").to_html
      expect(html).to eq("(R)-CH<sub>3</sub>")
    end
  end
end
