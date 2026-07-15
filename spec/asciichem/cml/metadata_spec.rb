# frozen_string_literal: true

require "spec_helper"
require "chemicalml"
require "asciichem/cml"

RSpec.describe "CML metadata round-trip" do
  before(:all) { Chemicalml::Cml::Schema3.ensure_registered! }

  def build_molecule_with_metadata
    AsciiChem::Model::Molecule.new(
      nodes: [
        AsciiChem::Model::Atom.new(element: "H", subscript: "2"),
        AsciiChem::Model::Atom.new(element: "O")
      ],
      names: [AsciiChem::Model::Name.new(content: "Water")],
      identifiers: [
        AsciiChem::Model::Identifier.new(value: "InChI=1/H2O/h1H2", convention: "inchi")
      ]
    )
  end

  describe "names" do
    it "emits <name> in CML output" do
      formula = AsciiChem::Model::Formula.new(nodes: [build_molecule_with_metadata])
      xml = AsciiChem::Cml.from_asciichem(formula)
      expect(xml).to include("<name>Water</name>")
    end

    it "preserves name content through round-trip" do
      formula = AsciiChem::Model::Formula.new(nodes: [build_molecule_with_metadata])
      back = AsciiChem::Cml.parse(AsciiChem::Cml.from_asciichem(formula))
      expect(back.nodes.first.names.first.content).to eq("Water")
    end

    it "preserves name convention through round-trip" do
      mol = AsciiChem::Model::Molecule.new(
        nodes: [AsciiChem::Model::Atom.new(element: "C")],
        names: [AsciiChem::Model::Name.new(content: "methane", convention: "iupac")]
      )
      formula = AsciiChem::Model::Formula.new(nodes: [mol])
      back = AsciiChem::Cml.parse(AsciiChem::Cml.from_asciichem(formula))
      expect(back.nodes.first.names.first.convention).to eq("iupac")
    end
  end

  describe "identifiers" do
    it "emits <identifier> in CML output" do
      formula = AsciiChem::Model::Formula.new(nodes: [build_molecule_with_metadata])
      xml = AsciiChem::Cml.from_asciichem(formula)
      expect(xml).to include("<identifier")
      expect(xml).to include('value="InChI=1/H2O/h1H2"')
      expect(xml).to include('convention="inchi"')
    end

    it "preserves identifier value through round-trip" do
      formula = AsciiChem::Model::Formula.new(nodes: [build_molecule_with_metadata])
      back = AsciiChem::Cml.parse(AsciiChem::Cml.from_asciichem(formula))
      id = back.nodes.first.identifiers.first
      expect(id.value).to eq("InChI=1/H2O/h1H2")
      expect(id.convention).to eq("inchi")
    end

    it "preserves multiple identifiers" do
      mol = AsciiChem::Model::Molecule.new(
        nodes: [AsciiChem::Model::Atom.new(element: "C")],
        identifiers: [
          AsciiChem::Model::Identifier.new(value: "C", convention: "smiles"),
          AsciiChem::Model::Identifier.new(value: "74-82-8", convention: "cas")
        ]
      )
      formula = AsciiChem::Model::Formula.new(nodes: [mol])
      back = AsciiChem::Cml.parse(AsciiChem::Cml.from_asciichem(formula))
      ids = back.nodes.first.identifiers
      expect(ids.length).to eq(2)
      expect(ids.map(&:convention)).to contain_exactly("smiles", "cas")
    end
  end

  describe "molecules without metadata" do
    it "produces clean CML with no <name> or <identifier>" do
      formula = AsciiChem.parse("H_2O")
      xml = AsciiChem::Cml.from_asciichem(formula)
      expect(xml).not_to include("<name")
      expect(xml).not_to include("<identifier")
    end

    it "round-trips normally (no regression)" do
      formula = AsciiChem.parse("H_2O")
      back = AsciiChem::Cml.parse(AsciiChem::Cml.from_asciichem(formula))
      expect(back.to_text).to eq("H_2O")
    end
  end
end
