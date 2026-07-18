# frozen_string_literal: true

require "spec_helper"
require "chemicalml"
require "asciichem/cml"

RSpec.describe AsciiChem::Cml::Extensions do
  before(:all) { Chemicalml::Cml::Schema3.ensure_registered! }

  describe ".collect" do
    it "returns an empty map when no atoms have extension data" do
      formula = AsciiChem.parse("H_2O")
      translation = AsciiChem::ModelAdapter.to_canonical_with_mapping(formula)
      extensions = described_class.collect(translation.atom_mapping)
      expect(extensions).to be_empty
    end

    it "includes oxidation_state when set" do
      formula = AsciiChem.parse("Fe^(II)")
      translation = AsciiChem::ModelAdapter.to_canonical_with_mapping(formula)
      extensions = described_class.collect(translation.atom_mapping)
      expect(extensions).to include("a1" => { oxidation_state: "II" })
    end

    it "includes lone_pairs when set" do
      formula = AsciiChem.parse("::O")
      translation = AsciiChem::ModelAdapter.to_canonical_with_mapping(formula)
      extensions = described_class.collect(translation.atom_mapping)
      expect(extensions).to include("a1" => { lone_pairs: 2 })
    end

    it "includes radical_electrons when set" do
      formula = AsciiChem.parse("N.")
      translation = AsciiChem::ModelAdapter.to_canonical_with_mapping(formula)
      extensions = described_class.collect(translation.atom_mapping)
      expect(extensions).to include("a1" => { radical_electrons: 1 })
    end

    it "combines multiple fields on one atom" do
      formula = AsciiChem.parse("::N.")
      translation = AsciiChem::ModelAdapter.to_canonical_with_mapping(formula)
      extensions = described_class.collect(translation.atom_mapping)
      expect(extensions["a1"]).to eq({ lone_pairs: 2, radical_electrons: 1 })
    end

    it "skips atoms without extension data" do
      formula = AsciiChem.parse("H-O-H")
      translation = AsciiChem::ModelAdapter.to_canonical_with_mapping(formula)
      extensions = described_class.collect(translation.atom_mapping)
      expect(extensions).to be_empty
    end
  end

  describe ".inject and .extract" do
    it "round-trips extension data through XML" do
      formula = AsciiChem.parse("Fe^(II)")
      translation = AsciiChem::ModelAdapter.to_canonical_with_mapping(formula)
      wire_doc = translation.document
      xml = wire_doc.to_xml

      extensions = described_class.collect(translation.atom_mapping)
      enriched = described_class.inject(xml, extensions)
      extracted = described_class.extract(enriched)

      expect(extracted).to eq(extensions)
    end

    it "is a no-op for empty extensions" do
      xml = "<cml/>"
      result = described_class.inject(xml, {})
      expect(result).to eq(xml)
    end

    it "preserves the CML namespace" do
      formula = AsciiChem.parse("Fe^(II)")
      translation = AsciiChem::ModelAdapter.to_canonical_with_mapping(formula)
      wire_doc = translation.document
      xml = wire_doc.to_xml
      extensions = described_class.collect(translation.atom_mapping)
      enriched = described_class.inject(xml, extensions)

      expect(enriched).to include('xmlns="http://www.xml-cml.org/schema"')
      expect(enriched).to include('xmlns:aci="https://asciichem.org/cml-ext"')
    end

    it "does not declare aci: namespace when no extensions are present" do
      formula = AsciiChem.parse("H_2O")
      translation = AsciiChem::ModelAdapter.to_canonical_with_mapping(formula)
      wire_doc = translation.document
      xml = wire_doc.to_xml

      extensions = described_class.collect(translation.atom_mapping)
      expect(extensions).to be_empty
      expect(described_class.inject(xml, extensions)).not_to include("aci:")
    end

    it "extracts from XML produced by another tool that uses aci:" do
      xml = <<~CML
        <?xml version="1.0"?>
        <cml xmlns="http://www.xml-cml.org/schema" xmlns:aci="https://asciichem.org/cml-ext">
          <molecule id="m1">
            <atomArray>
              <atom id="a1" elementType="Fe" aci:oxidationState="III"/>
            </atomArray>
          </molecule>
        </cml>
      CML
      extracted = described_class.extract(xml)
      expect(extracted).to eq("a1" => { oxidation_state: "III" })
    end
  end

  describe ".restore" do
    it "applies extracted extension data to a parsed formula" do
      source = "Fe^(II)"
      xml = AsciiChem.parse(source).to_cml
      formula = AsciiChem::Cml.parse(xml)
      atom = formula.nodes.first.nodes.first
      expect(atom.oxidation_state).to eq("II")
    end

    it "is a no-op when extensions is empty" do
      formula = AsciiChem.parse("H_2O")
      canonical = AsciiChem::ModelAdapter.to_canonical(formula)
      described_class.restore(formula, canonical, {})
      # No assertions on values — just verify no exception.
    end

    it "preserves lone_pairs as integers, not strings" do
      xml = AsciiChem.parse("::O").to_cml
      formula = AsciiChem::Cml.parse(xml)
      atom = formula.nodes.first.nodes.first
      expect(atom.lone_pairs).to eq(2)
      expect(atom.lone_pairs).to be_an(Integer)
    end

    it "preserves radical_electrons as integers" do
      xml = AsciiChem.parse("N.").to_cml
      formula = AsciiChem::Cml.parse(xml)
      atom = formula.nodes.first.nodes.first
      expect(atom.radical_electrons).to eq(1)
      expect(atom.radical_electrons).to be_an(Integer)
    end
  end

  describe "FIELDS registry" do
    it "is frozen (extension point, not runtime-mutable)" do
      expect(described_class::FIELDS).to be_frozen
    end

    it "covers all aci: extension fields" do
      expect(described_class::FIELDS.keys)
        .to contain_exactly(:oxidation_state, :lone_pairs, :radical_electrons, :ring_closures, :atom_parity)
    end

    it "maps each Ruby attribute to a distinct wire name" do
      wire_names = described_class::FIELDS.values
      expect(wire_names).to eq(wire_names.uniq)
    end
  end

  describe "TOP_LEVEL_HANDLERS registry" do
    it "is frozen" do
      expect(described_class::TOP_LEVEL_HANDLERS).to be_frozen
    end

    it "covers all top-level constructs including beyond-formulas" do
      classes = described_class::TOP_LEVEL_HANDLERS.map(&:node_class)
      expect(classes).to contain_exactly(
        AsciiChem::Model::ElectronConfiguration,
        AsciiChem::Model::EmbeddedMath,
        AsciiChem::Model::Text,
        AsciiChem::Model::Crystal,
        AsciiChem::Model::Spectrum,
        AsciiChem::Model::Calculation,
        AsciiChem::Model::ZMatrix,
        AsciiChem::Model::Mechanism
      )
    end

    it "maps each handler to a distinct element name" do
      element_names = described_class::TOP_LEVEL_HANDLERS.map(&:element_name)
      expect(element_names).to eq(element_names.uniq)
    end
  end

  describe ".collect_top_level" do
    it "returns empty array for a formula with no top-level extensions" do
      formula = AsciiChem.parse("H_2O")
      expect(described_class.collect_top_level(formula)).to eq([])
    end

    it "collects an ElectronConfiguration with its position" do
      formula = AsciiChem.parse("1s^2 2s^2")
      result = described_class.collect_top_level(formula)
      expect(result.length).to eq(1)
      expect(result.first[:position]).to eq(0)
      expect(result.first[:element_name]).to eq("electronConfiguration")
      expect(result.first[:content]).to eq("1s^2 2s^2")
    end

    it "collects an EmbeddedMath with its source" do
      formula = AsciiChem.parse("`K_c = 1`")
      result = described_class.collect_top_level(formula)
      expect(result.first[:element_name]).to eq("embeddedMath")
      expect(result.first[:content]).to eq("K_c = 1")
    end

    it "records the correct position when extension follows other nodes" do
      formula = AsciiChem.parse("H_2O 1s^2 2s^2")
      result = described_class.collect_top_level(formula)
      expect(result.first[:position]).to eq(1)
    end
  end

  describe ".inject_top_level and .extract_top_level" do
    it "round-trips top-level extensions through XML" do
      formula = AsciiChem.parse("1s^2 2s^2")
      translation = AsciiChem::ModelAdapter.to_canonical_with_mapping(formula)
      wire_doc = translation.document
      base_xml = wire_doc.to_xml

      top_level = described_class.collect_top_level(formula)
      enriched = described_class.inject_top_level(base_xml, top_level)
      extracted = described_class.extract_top_level(enriched)

      expect(extracted).to eq(top_level)
    end

    it "is a no-op for empty top-level list" do
      result = described_class.inject_top_level("<cml/>", [])
      expect(result).to eq("<cml/>")
    end

    it "extracts top-level extensions produced by another aci: producer" do
      xml = <<~CML
        <?xml version="1.0"?>
        <cml xmlns="http://www.xml-cml.org/schema" xmlns:aci="https://asciichem.org/cml-ext">
          <aci:electronConfiguration position="0">1s^2 2s^2 2p^6</aci:electronConfiguration>
        </cml>
      CML
      extracted = described_class.extract_top_level(xml)
      expect(extracted.first[:element_name]).to eq("electronConfiguration")
      expect(extracted.first[:content]).to eq("1s^2 2s^2 2p^6")
      expect(extracted.first[:position]).to eq(0)
    end

    it "escapes XML special characters in embedded math content" do
      xml = AsciiChem.parse("`a < b && c > d`").to_cml
      expect(xml).to include("&lt;")
      expect(xml).to include("&gt;")
      # And the round-trip restores the original
      formula = AsciiChem::Cml.parse(xml)
      math = formula.nodes.first
      expect(math).to be_a(AsciiChem::Model::EmbeddedMath)
      expect(math.source).to eq("a < b && c > d")
    end
  end

  describe ".restore_top_level" do
    it "inserts extensions at their original positions" do
      formula = AsciiChem.parse("H_2O")
      top_level = [
        { position: 0, element_name: "electronConfiguration", content: "1s^2 2s^2" }
      ]
      described_class.restore_top_level(formula, top_level)
      expect(formula.nodes.first).to be_a(AsciiChem::Model::ElectronConfiguration)
      expect(formula.nodes.last).to be_a(AsciiChem::Model::Molecule)
    end

    it "is a no-op when top-level is empty" do
      formula = AsciiChem.parse("H_2O")
      original = formula.nodes.dup
      described_class.restore_top_level(formula, [])
      expect(formula.nodes).to eq(original)
    end

    it "handles position beyond current length gracefully" do
      formula = AsciiChem.parse("H_2O")
      top_level = [
        { position: 10, element_name: "electronConfiguration", content: "1s^2 2s^2" }
      ]
      described_class.restore_top_level(formula, top_level)
      # Position 10 is clamped to the end.
      expect(formula.nodes.last).to be_a(AsciiChem::Model::ElectronConfiguration)
    end
  end
end
