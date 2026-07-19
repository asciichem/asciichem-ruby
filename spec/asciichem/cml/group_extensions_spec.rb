# frozen_string_literal: true

require "spec_helper"
require "chemicalml"
require "asciichem/cml"

RSpec.describe AsciiChem::Cml::GroupExtensions do
  before(:all) { Chemicalml::Cml::Schema3.ensure_registered! }

  describe ".collect" do
    it "returns empty hash for a molecule without groups" do
      translation = AsciiChem::ModelAdapter.to_canonical_with_mapping(AsciiChem.parse("H_2O"))
      expect(described_class.collect(translation.groups)).to eq({})
    end

    it "returns the group record for a grouped molecule" do
      translation = AsciiChem::ModelAdapter.to_canonical_with_mapping(AsciiChem.parse("(OH)_2"))
      collected = described_class.collect(translation.groups)
      expect(collected.keys).to contain_exactly("m1")
      group = collected["m1"].first
      expect(group.multiplicity).to eq("2")
      expect(group.bracket).to eq(:paren)
      expect(group.atom_ids).to eq(%w[a1 a2])
    end
  end

  describe ".inject and .extract" do
    it "round-trips group data through XML" do
      translation = AsciiChem::ModelAdapter.to_canonical_with_mapping(AsciiChem.parse("(OH)_2"))
      wire_doc = translation.document
      base_xml = wire_doc.to_xml

      collected = described_class.collect(translation.groups)
      enriched = described_class.inject(base_xml, collected)
      extracted = described_class.extract(enriched)

      expect(extracted.keys).to include("m1")
      record = extracted["m1"].first
      expect(record[:multiplicity]).to eq("2")
      expect(record[:bracket]).to eq(:paren)
      expect(record[:atom_ids]).to eq(%w[a1 a2])
    end

    it "is a no-op for empty groups map" do
      result = described_class.inject("<cml/>", {})
      expect(result).to eq("<cml/>")
    end

    it "preserves bracket kind through round-trip" do
      %w[[OH]_2 {OH}_2].each do |source|
        translation = AsciiChem::ModelAdapter.to_canonical_with_mapping(AsciiChem.parse(source))
        collected = described_class.collect(translation.groups)
        wire_doc = translation.document
        enriched = described_class.inject(wire_doc.to_xml, collected)
        extracted = described_class.extract(enriched)
        expected_bracket = source.start_with?("[") ? :square : :brace
        expect(extracted["m1"].first[:bracket]).to eq(expected_bracket)
      end
    end

    it "extracts from externally-produced aci:group XML" do
      xml = <<~CML
        <?xml version="1.0"?>
        <cml xmlns="http://www.xml-cml.org/schema" xmlns:aci="https://asciichem.org/cml-ext">
          <molecule id="m1">
            <atomArray>
              <atom id="a1" elementType="C"/>
              <atom id="a2" elementType="H" count="3"/>
            </atomArray>
            <aci:group multiplicity="4" bracket="paren" atomRefs="a1 a2"/>
          </molecule>
        </cml>
      CML
      extracted = described_class.extract(xml)
      expect(extracted["m1"].first[:multiplicity]).to eq("4")
      expect(extracted["m1"].first[:atom_ids]).to eq(%w[a1 a2])
    end
  end

  describe ".restore" do
    it "wraps referenced atoms in a Group node" do
      source = "(OH)_2"
      xml = AsciiChem.parse(source).to_cml
      formula = AsciiChem::Cml.parse(xml)
      molecule = formula.nodes.first
      expect(molecule.nodes.first).to be_a(AsciiChem::Model::Group)
      group = molecule.nodes.first
      expect(group.multiplicity).to eq("2")
      expect(group.bracket).to eq(:paren)
      expect(group.nodes.map(&:element)).to eq(%w[O H])
    end

    it "divides the atom count back to its pre-multiplicity value" do
      source = "(H_2O)_3"
      xml = AsciiChem.parse(source).to_cml
      formula = AsciiChem::Cml.parse(xml)
      group = formula.nodes.first.nodes.first
      atoms = group.nodes
      # Original H had subscript "2", was multiplied to "6", should
      # divide back to "2".
      expect(atoms.first.subscript).to eq("2")
      # Original O had no subscript, was multiplied to "3", should
      # divide back to nil.
      expect(atoms.last.subscript).to be_nil
    end

    it "preserves the group's position relative to other atoms" do
      source = "Ca(OH)_2"
      xml = AsciiChem.parse(source).to_cml
      formula = AsciiChem::Cml.parse(xml)
      molecule = formula.nodes.first
      # First node should be the bare Ca atom, second should be the Group.
      expect(molecule.nodes[0]).to be_a(AsciiChem::Model::Atom)
      expect(molecule.nodes[0].element).to eq("Ca")
      expect(molecule.nodes[1]).to be_a(AsciiChem::Model::Group)
    end

    it "is a no-op when groups map is empty" do
      formula = AsciiChem.parse("H_2O")
      canonical = AsciiChem::ModelAdapter.to_canonical(formula)
      described_class.restore(formula, canonical, {})
      # No exceptions; nodes should remain unchanged.
      expect(formula.nodes.first).to be_a(AsciiChem::Model::Molecule)
    end

    it "preserves square brackets" do
      source = "[OH]_2"
      xml = AsciiChem.parse(source).to_cml
      formula = AsciiChem::Cml.parse(xml)
      group = formula.nodes.first.nodes.first
      expect(group.bracket).to eq(:square)
    end

    it "preserves brace brackets" do
      source = "{OH}_2"
      xml = AsciiChem.parse(source).to_cml
      formula = AsciiChem::Cml.parse(xml)
      group = formula.nodes.first.nodes.first
      expect(group.bracket).to eq(:brace)
    end
  end

  describe "full CML round-trip" do
    cases = [
      "(OH)_2",
      "(H_2O)_3",
      "Ca(OH)_2",
      "[OH]_2",
      "{OH}_2",
      "(H_2)_12",  # group with multi-digit multiplicity
      # Nested groups — the walker tracks nesting, restore rebuilds it.
      "((OH))",       # outer group with no mult, inner group with no mult
      "((OH)_2)",     # outer no mult, inner mult=2
      "Ca((OH)_2)"    # nested group inside a larger molecule
    ]

    cases.each do |source|
      it "round-trips #{source.inspect} through CML" do
        round_trip = AsciiChem::Cml.parse(AsciiChem.parse(source).to_cml).to_text
        expect(round_trip).to eq(source)
      end
    end
  end

  describe "nested group structure" do
    it "preserves Group-inside-Group nesting" do
      source = "((OH)_2)"
      xml = AsciiChem.parse(source).to_cml
      formula = AsciiChem::Cml.parse(xml)
      outer = formula.nodes.first.nodes.first
      expect(outer).to be_a(AsciiChem::Model::Group)
      expect(outer.multiplicity).to be_nil
      inner = outer.nodes.first
      expect(inner).to be_a(AsciiChem::Model::Group)
      expect(inner.multiplicity).to eq("2")
      expect(inner.nodes.map(&:element)).to eq(%w[O H])
    end

    it "preserves deeply nested group inside a larger molecule" do
      source = "Ca((OH)_2)"
      xml = AsciiChem.parse(source).to_cml
      formula = AsciiChem::Cml.parse(xml)
      molecule = formula.nodes.first
      # First node: bare Ca atom.
      expect(molecule.nodes[0]).to be_a(AsciiChem::Model::Atom)
      expect(molecule.nodes[0].element).to eq("Ca")
      # Second node: outer Group (no mult) wrapping inner Group.
      outer = molecule.nodes[1]
      expect(outer).to be_a(AsciiChem::Model::Group)
      expect(outer.multiplicity).to be_nil
      inner = outer.nodes.first
      expect(inner).to be_a(AsciiChem::Model::Group)
      expect(inner.multiplicity).to eq("2")
    end
  end

  describe "Group::BRACKETS registry" do
    let(:brackets) { AsciiChem::Model::Group::BRACKETS }

    it "is frozen" do
      expect(brackets).to be_frozen
    end

    it "covers paren, square, brace" do
      expect(brackets.keys)
        .to contain_exactly(:paren, :square, :brace)
    end

    it "is invertible via BRACKET_BY_WIRE" do
      expect(AsciiChem::Model::Group::BRACKET_BY_WIRE)
        .to eq(brackets.to_h { |k, v| [v[:wire], k] })
    end
  end
end
