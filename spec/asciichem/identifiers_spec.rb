# frozen_string_literal: true

require "spec_helper"

RSpec.describe AsciiChem::Identifiers do
  describe "registry" do
    it "exposes the built-in conventions" do
      expect(described_class.known?("cas")).to be true
      expect(described_class.known?("inchi")).to be true
      expect(described_class.known?("inchikey")).to be true
      expect(described_class.known?("smiles")).to be true
    end

    it "normalises Symbol conventions" do
      expect(described_class.known?(:cas)).to be true
      expect(described_class[:inchi]).to eq(AsciiChem::Identifiers::Inchi)
      expect(described_class.valid?(:cas, "7732-18-5")).to be true
    end

    it "reports unknown conventions as not checkable" do
      expect(described_class.known?("iupac")).to be false
      expect(described_class.valid?("iupac", "methane")).to be false
      expect(described_class.diagnostic("cid", "1234")).to be_nil
    end
  end

  describe "CAS Registry Numbers" do
    it "accepts known-good registry numbers" do
      %w[7732-18-5 50-78-2 74-82-8 58-08-2 64-17-5].each do |cas|
        expect(described_class.valid?("cas", cas)).to be(true), cas
      end
    end

    it "rejects a wrong check digit" do
      expect(described_class.diagnostic("cas", "7732-18-6"))
        .to match(/check digit 6 does not match weighted sum \(5\)/)
    end

    it "rejects malformed formats" do
      %w[50782 7-73-2 7732_18_5 7732-185-5 7732-18 a7-73-2].each do |cas|
        expect(described_class.diagnostic("cas", cas)).to match(/not in DDDDDDD-DD-D form/), cas
      end
    end
  end

  describe "InChI" do
    let(:aspirin) { "InChI=1S/C9H8O4/c1-6(10)13-8-5-3-2-4-7(8)9(11)12/h2-5H,1H3,(H,11,12)" }

    it "accepts standard and non-standard prefixes with layers" do
      expect(described_class.valid?("inchi", "InChI=1S/CH4/h1H4")).to be true
      expect(described_class.valid?("inchi", "InChI=1/CH4/h1H4")).to be true
      expect(described_class.valid?("inchi", aspirin)).to be true
    end

    it "rejects a bad prefix or version" do
      expect(described_class.diagnostic("inchi", "InChI=2S/CH4")).to match(/must start with/)
      expect(described_class.diagnostic("inchi", "inchI=1S/CH4")).to match(/must start with/)
    end

    it "rejects an empty formula layer" do
      expect(described_class.diagnostic("inchi", "InChI=1S/")).to match(/formula layer is empty/)
    end

    it "rejects malformed or unknown elements in the formula layer" do
      expect(described_class.diagnostic("inchi", "InChI=1S/Cx4/h1H4"))
        .to match(/unknown element symbol "Cx"/)
      expect(described_class.diagnostic("inchi", "InChI=1S/9CH")).to match(/malformed formula layer/)
    end

    describe ".formula_counts" do
      it "extracts element counts from the formula layer" do
        expect(described_class::Inchi.formula_counts(aspirin))
          .to eq("C" => 9, "H" => 8, "O" => 4)
        expect(described_class::Inchi.formula_counts("InChI=1S/CH4/h1H4"))
          .to eq("C" => 1, "H" => 4)
      end

      it "returns nil for unanalysable values" do
        expect(described_class::Inchi.formula_counts("garbage")).to be_nil
      end
    end
  end

  describe "InChIKey" do
    let(:aspirin_key) { "BSYNRYMUTXBXSQ-UHFFFAOYSA-N" }

    it "accepts a well-formed key" do
      expect(described_class.valid?("inchikey", aspirin_key)).to be true
    end

    it "rejects corruptions" do
      expect(described_class.diagnostic("inchikey", aspirin_key.downcase))
        .to match(/27 uppercase letters/)
      expect(described_class.diagnostic("inchikey", "BSYNRYMUTXBXSQZ-UHFFFAOYSA-N"))
        .to match(/27 uppercase letters/)
      expect(described_class.diagnostic("inchikey", "BSYNRYMUTXBXSQ-UHFFFAOYSA"))
        .to match(/27 uppercase letters/)
      expect(described_class.diagnostic("inchikey", "BSYNRYMUTXBXSQ-UHFFFAOYSA-NN"))
        .to match(/27 uppercase letters/)
      expect(described_class.diagnostic("inchikey", "BSYNRYMUTXBXSQUHFFFAOYSAN"))
        .to match(/27 uppercase letters/)
    end
  end

  describe "SMILES sanity" do
    it "accepts plausible SMILES including aromatic forms" do
      [
        "CCO",
        "C(=O)O",
        "C1CCCCC1",
        "[13CH4]",
        "[Na+].[Cl-]",
        "c1ccccc1",
        "CC(=O)Oc1ccccc1C(=O)O"
      ].each do |smiles|
        expect(described_class.valid?("smiles", smiles)).to be(true), smiles
      end
    end

    it "rejects whitespace, imbalance, unpaired rings, unknown elements" do
      expect(described_class.diagnostic("smiles", "")).to match(/must not be empty/)
      expect(described_class.diagnostic("smiles", "C C")).to match(/must not contain whitespace/)
      expect(described_class.diagnostic("smiles", "C(C")).to match(/parentheses are not balanced/)
      expect(described_class.diagnostic("smiles", "[C")).to match(/square brackets are not balanced/)
      expect(described_class.diagnostic("smiles", "C1CCC")).to match(/ring-bond digit 1/)
      expect(described_class.diagnostic("smiles", "CX")).to match(/unknown element token/)
    end

    describe ".element_set" do
      it "collects unique elements, normalising aromatic atoms" do
        expect(described_class::Smiles.element_set("c1ccccc1C(=O)O")).to eq(%w[C O])
        expect(described_class::Smiles.element_set("[Na+].[Cl-]")).to eq(%w[Cl Na])
      end

      it "returns nil when not analysable" do
        expect(described_class::Smiles.element_set("CX")).to be_nil
        expect(described_class::Smiles.element_set("C(C")).to be_nil
      end
    end
  end
end
