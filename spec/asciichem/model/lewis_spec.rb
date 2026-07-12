# frozen_string_literal: true

require "spec_helper"

RSpec.describe AsciiChem::Model::Atom do
  describe "Lewis markers" do
    it "defaults lone_pairs and radical_electrons to nil" do
      atom = described_class.new(element: "O")
      expect(atom.lone_pairs).to be_nil
      expect(atom.radical_electrons).to be_nil
    end

    it "stores lone_pairs as integer" do
      atom = described_class.new(element: "O", lone_pairs: 2)
      expect(atom.lone_pairs).to eq(2)
    end

    it "stores radical_electrons as integer" do
      atom = described_class.new(element: "Cl", radical_electrons: 1)
      expect(atom.radical_electrons).to eq(1)
    end
  end

  describe "parser integration" do
    it "parses prefix `:` as lone pairs" do
      atom = AsciiChem.parse(":O").nodes.first.nodes.first
      expect(atom.lone_pairs).to eq(1)
    end

    it "parses multiple `:` as that many lone pairs" do
      atom = AsciiChem.parse("::O").nodes.first.nodes.first
      expect(atom.lone_pairs).to eq(2)
    end

    it "parses suffix `.` as radical electrons" do
      atom = AsciiChem.parse("Cl.").nodes.first.nodes.first
      expect(atom.radical_electrons).to eq(1)
    end

    it "parses multiple `.` as multiple radicals" do
      atom = AsciiChem.parse("O=O..").nodes.first.nodes.last
      expect(atom.radical_electrons).to eq(2)
    end

    it "combines lone pairs and radicals" do
      atom = AsciiChem.parse(":O.").nodes.first.nodes.first
      expect(atom.lone_pairs).to eq(1)
      expect(atom.radical_electrons).to eq(1)
    end
  end

  describe "round-trip" do
    it "round-trips lone pairs" do
      expect(AsciiChem.parse(":O").to_text).to eq(":O")
      expect(AsciiChem.parse("::O").to_text).to eq("::O")
    end

    it "round-trips radicals" do
      expect(AsciiChem.parse("Cl.").to_text).to eq("Cl.")
      expect(AsciiChem.parse("O=O..").to_text).to eq("O=O..")
    end

    it "round-trips combined Lewis markers" do
      expect(AsciiChem.parse(":O.").to_text).to eq(":O.")
    end
  end

  describe "formatters" do
    it "emits Lewis markers in MathML" do
      xml = AsciiChem.parse(":O").to_mathml
      expect(xml).to include(":")
      expect(xml).to include('mathvariant="normal">O<')
    end

    it "emits Lewis markers in LaTeX inside ce{}" do
      latex = AsciiChem.parse(":O").to_latex
      expect(latex).to eq("\\ce{:O}")
    end
  end
end
