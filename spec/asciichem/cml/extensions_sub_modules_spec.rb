# frozen_string_literal: true

require "spec_helper"
require "chemicalml"
require "asciichem/cml"

RSpec.describe AsciiChem::Cml::Extensions::AtomAttributes do
  before(:all) { Chemicalml::Cml::Schema3.ensure_registered! }

  describe ".collect" do
    it "returns empty map when no atoms have extension data" do
      formula = AsciiChem.parse("H_2O")
      translation = AsciiChem::ModelAdapter.to_canonical_with_mapping(formula)
      expect(described_class.collect(translation.atom_mapping)).to be_empty
    end

    it "includes oxidation_state when set" do
      formula = AsciiChem.parse("Fe^(II)")
      translation = AsciiChem::ModelAdapter.to_canonical_with_mapping(formula)
      result = described_class.collect(translation.atom_mapping)
      expect(result).to include("a1" => { oxidation_state: "II" })
    end

    it "includes lone_pairs as integer" do
      formula = AsciiChem.parse("::O")
      translation = AsciiChem::ModelAdapter.to_canonical_with_mapping(formula)
      result = described_class.collect(translation.atom_mapping)
      expect(result).to include("a1" => { lone_pairs: 2 })
    end
  end

  describe ".inject and .extract" do
    it "is a no-op for empty extensions" do
      expect(described_class.inject("<cml/>", {})).to eq("<cml/>")
    end

    it "does not declare aci: namespace when no extensions present" do
      formula = AsciiChem.parse("H_2O")
      translation = AsciiChem::ModelAdapter.to_canonical_with_mapping(formula)
      xml = translation.document.to_xml
      extensions = described_class.collect(translation.atom_mapping)
      expect(extensions).to be_empty
      expect(described_class.inject(xml, extensions)).not_to include("aci:")
    end

    it "round-trips extension data through XML" do
      formula = AsciiChem.parse("Fe^(II)")
      translation = AsciiChem::ModelAdapter.to_canonical_with_mapping(formula)
      xml = translation.document.to_xml
      extensions = described_class.collect(translation.atom_mapping)
      enriched = described_class.inject(xml, extensions)
      extracted = described_class.extract(enriched)
      expect(extracted).to eq(extensions)
    end
  end

  describe "FIELDS registry" do
    it "is frozen" do
      expect(described_class::FIELDS).to be_frozen
    end

    it "maps Ruby attribute names to wire attribute names" do
      expect(described_class::FIELDS[:oxidation_state]).to eq("oxidationState")
      expect(described_class::FIELDS[:lone_pairs]).to eq("lonePairs")
    end
  end
end

RSpec.describe AsciiChem::Cml::Extensions::TopLevel do
  before(:all) { Chemicalml::Cml::Schema3.ensure_registered! }

  describe ".collect" do
    it "returns empty array for a formula with no top-level constructs" do
      formula = AsciiChem.parse("H_2O")
      expect(described_class.collect(formula)).to eq([])
    end

    it "collects an ElectronConfiguration at position 0" do
      formula = AsciiChem.parse("1s^2 2s^2")
      result = described_class.collect(formula)
      expect(result.length).to eq(1)
      expect(result.first[:position]).to eq(0)
      expect(result.first[:element_name]).to eq("electronConfiguration")
    end

    it "records the correct position when extension follows other nodes" do
      formula = AsciiChem.parse("H_2O 1s^2 2s^2")
      result = described_class.collect(formula)
      expect(result.first[:position]).to eq(1)
    end
  end

  describe ".inject and .extract" do
    it "round-trips top-level constructs through XML" do
      formula = AsciiChem.parse("1s^2 2s^2")
      translation = AsciiChem::ModelAdapter.to_canonical_with_mapping(formula)
      base_xml = translation.document.to_xml
      top_level = described_class.collect(formula)
      enriched = described_class.inject(base_xml, top_level)
      extracted = described_class.extract(enriched)
      expect(extracted).to eq(top_level)
    end

    it "is a no-op for empty top-level list" do
      expect(described_class.inject("<cml/>", [])).to eq("<cml/>")
    end
  end

  describe "HANDLERS registry" do
    it "covers all eight construct classes" do
      classes = described_class::HANDLERS.map(&:node_class)
      expect(classes.length).to eq(8)
      expect(classes).to include(AsciiChem::Model::Crystal,
                                 AsciiChem::Model::Mechanism)
    end
  end
end
