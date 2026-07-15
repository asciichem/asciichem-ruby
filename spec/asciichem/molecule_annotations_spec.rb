# frozen_string_literal: true

require "spec_helper"
require "chemicalml"
require "asciichem/cml"

RSpec.describe "molecule annotation syntax" do
  before(:all) { Chemicalml::Cml::Schema3.ensure_registered! }

  describe "@name annotation" do
    it "parses and attaches a Name to the molecule" do
      mol = AsciiChem.parse('H_2O @name("Water")').nodes.first
      expect(mol.names.first.content).to eq("Water")
    end

    it "round-trips through Text" do
      expect(AsciiChem.parse('H_2O @name("Water")').to_text).to eq('H_2O @name("Water")')
    end

    it "round-trips through CML" do
      src = 'H_2O @name("Water")'
      result = AsciiChem::Cml.parse(AsciiChem.parse(src).to_cml).to_text
      expect(result).to eq(src)
    end
  end

  describe "@inchi annotation" do
    it "attaches an Identifier with convention inchi" do
      mol = AsciiChem.parse('C @inchi("InChI=1/C")').nodes.first
      expect(mol.identifiers.first.convention).to eq("inchi")
      expect(mol.identifiers.first.value).to eq("InChI=1/C")
    end

    it "round-trips through CML" do
      src = 'C @inchi("InChI=1/C")'
      result = AsciiChem::Cml.parse(AsciiChem.parse(src).to_cml).to_text
      expect(result).to eq(src)
    end
  end

  describe "@smiles annotation" do
    it "attaches an Identifier with convention smiles" do
      mol = AsciiChem.parse('C @smiles("C")').nodes.first
      expect(mol.identifiers.first.convention).to eq("smiles")
    end
  end

  describe "@cas annotation" do
    it "attaches an Identifier with convention cas" do
      mol = AsciiChem.parse('C @cas("74-82-8")').nodes.first
      expect(mol.identifiers.first.convention).to eq("cas")
      expect(mol.identifiers.first.value).to eq("74-82-8")
    end
  end

  describe "@title annotation" do
    it "sets the molecule title" do
      mol = AsciiChem.parse('H_2O @title("water molecule")').nodes.first
      expect(mol.title).to eq("water molecule")
    end

    it "round-trips through Text" do
      expect(AsciiChem.parse('H_2O @title("water molecule")').to_text)
        .to eq('H_2O @title("water molecule")')
    end
  end

  describe "@formula annotation" do
    it "adds a concise formula" do
      mol = AsciiChem.parse('H_2O @formula("H 2 O 1")').nodes.first
      expect(mol.formulas.first[:concise]).to eq("H 2 O 1")
    end

    it "round-trips through Text" do
      expect(AsciiChem.parse('H_2O @formula("H 2 O 1")').to_text)
        .to eq('H_2O @formula("H 2 O 1")')
    end
  end

  describe "@label annotation" do
    it "adds a label" do
      mol = AsciiChem.parse('H_2O @label("solvent")').nodes.first
      expect(mol.labels.first[:value]).to eq("solvent")
    end
  end

  describe "multiple annotations" do
    it "parses name + inchi chained" do
      src = 'H_2O @name("Water")@inchi("InChI=1/H2O/h1H2")'
      mol = AsciiChem.parse(src).nodes.first
      expect(mol.names.first.content).to eq("Water")
      expect(mol.identifiers.first.convention).to eq("inchi")
    end

    it "round-trips multiple annotations through Text" do
      src = 'H_2O @name("Water")@inchi("InChI=1/H2O/h1H2")'
      expect(AsciiChem.parse(src).to_text).to eq(src)
    end

    it "round-trips multiple annotations through CML" do
      src = 'H_2O @name("Water")@smiles("O")'
      result = AsciiChem::Cml.parse(AsciiChem.parse(src).to_cml).to_text
      expect(result).to eq(src)
    end
  end

  describe "molecules without annotations" do
    it "produce clean output (no @)" do
      expect(AsciiChem.parse("H_2O").to_text).to eq("H_2O")
      expect(AsciiChem.parse("H_2O").to_text).not_to include("@")
    end
  end
end
