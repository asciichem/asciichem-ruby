# frozen_string_literal: true

require "spec_helper"
require "chemicalml"
require "asciichem/cml"

RSpec.describe AsciiChem::Cml::OpaqueExtensions do
  before(:all) { Chemicalml::Cml::Schema3.ensure_registered! }

  describe ".extract" do
    it "returns empty list for CML with no unknown elements" do
      xml = "<cml xmlns=\"http://www.xml-cml.org/schema\"><molecule id=\"m1\"><atomArray><atom id=\"a1\" elementType=\"H\"/></atomArray></molecule></cml>"
      list, _cleaned = described_class.extract(xml)
      expect(list).to be_empty
    end

    it "extracts unknown top-level elements with their position and raw XML" do
      xml = <<~CML
        <?xml version="1.0"?>
        <cml xmlns="http://www.xml-cml.org/schema">
          <molecule id="m1"><atomArray><atom id="a1" elementType="H"/></atomArray></molecule>
          <table xmlns="http://other.ns"><tr><td>data</td></tr></table>
        </cml>
      CML
      list, _cleaned = described_class.extract(xml)
      expect(list.length).to eq(1)
      expect(list.first[:position]).to eq(1)
      expect(list.first[:element_name]).to eq("table")
      expect(list.first[:raw_xml]).to include("<table")
      expect(list.first[:raw_xml]).to include("<td>data</td>")
    end

    it "removes the unknown elements from the cleaned XML" do
      xml = <<~CML
        <cml xmlns="http://www.xml-cml.org/schema">
          <molecule id="m1"/>
          <custom xmlns="http://other.ns">data</custom>
        </cml>
      CML
      _list, cleaned = described_class.extract(xml)
      expect(cleaned).not_to include("<custom")
    end

    it "skips aci: namespace elements" do
      xml = <<~CML
        <cml xmlns="http://www.xml-cml.org/schema" xmlns:aci="https://asciichem.org/cml-ext">
          <aci:electronConfiguration position="0">1s^2</aci:electronConfiguration>
        </cml>
      CML
      list, _cleaned = described_class.extract(xml)
      expect(list).to be_empty
    end

    it "handles multiple unknown elements in document order" do
      xml = <<~CML
        <cml xmlns="http://www.xml-cml.org/schema">
          <molecule id="m1"/>
          <x:foo xmlns:x="http://x">1</x:foo>
          <y:bar xmlns:y="http://y">2</y:bar>
        </cml>
      CML
      list, _cleaned = described_class.extract(xml)
      expect(list.map { |e| e[:element_name] }).to eq(%w[foo bar])
      expect(list.map { |e| e[:position] }).to eq([1, 2])
    end
  end

  describe ".collect and .inject" do
    it "round-trips OpaqueCml through XML" do
      formula = AsciiChem::Model::Formula.new(nodes: [
        AsciiChem::Model::Molecule.new(
          nodes: [AsciiChem::Model::Atom.new(element: "H")]
        ),
        AsciiChem::Model::OpaqueCml.new(
          element_name: "table",
          raw_xml: "<table xmlns=\"http://x\"><tr><td>data</td></tr></table>"
        )
      ])
      xml = AsciiChem::Cml.from_asciichem(formula)
      expect(xml).to include("<table")
      expect(xml).to include("<td>data</td>")
    end

    it "places OpaqueCml between molecules in correct order" do
      formula = AsciiChem::Model::Formula.new(nodes: [
        AsciiChem::Model::Molecule.new(
          nodes: [AsciiChem::Model::Atom.new(element: "H")]
        ),
        AsciiChem::Model::OpaqueCml.new(
          element_name: "annot",
          raw_xml: "<annot xmlns=\"http://x\">mid</annot>"
        ),
        AsciiChem::Model::Molecule.new(
          nodes: [AsciiChem::Model::Atom.new(element: "O")]
        )
      ])
      xml = AsciiChem::Cml.from_asciichem(formula)
      # annot should appear between the two molecules
      expect(xml).to match(/molecule.*m1.*annot.*molecule.*m2.*<\/cml>/m)
    end

    it "is a no-op for formulas with no OpaqueCml" do
      formula = AsciiChem.parse("H_2O")
      xml = AsciiChem::Cml.from_asciichem(formula)
      expect(xml).not_to include("aci:")
    end
  end

  describe ".restore" do
    it "inserts OpaqueCml nodes at recorded positions" do
      formula = AsciiChem.parse("H_2O")
      opaque_list = [
        { position: 0, element_name: "custom", raw_xml: "<custom/>" }
      ]
      described_class.restore(formula, opaque_list)
      expect(formula.nodes.first).to be_an(AsciiChem::Model::OpaqueCml)
      expect(formula.nodes.first.element_name).to eq("custom")
    end

    it "clamps position to current length" do
      formula = AsciiChem.parse("H_2O")
      opaque_list = [
        { position: 50, element_name: "tail", raw_xml: "<tail/>" }
      ]
      described_class.restore(formula, opaque_list)
      expect(formula.nodes.last).to be_an(AsciiChem::Model::OpaqueCml)
    end

    it "is a no-op when opaque_list is empty" do
      formula = AsciiChem.parse("H_2O")
      original = formula.nodes.dup
      described_class.restore(formula, [])
      expect(formula.nodes).to eq(original)
    end
  end

  describe "full CML round-trip" do
    it "preserves unknown elements through parse → emit → parse" do
      xml = <<~CML
        <?xml version="1.0"?>
        <cml xmlns="http://www.xml-cml.org/schema">
          <molecule id="m1">
            <atomArray>
              <atom id="a1" elementType="H"/>
              <atom id="a2" elementType="O"/>
            </atomArray>
          </molecule>
          <experimentalNotes xmlns="http://lab.ns">
            <note>Sample prepared under argon.</note>
          </experimentalNotes>
        </cml>
      CML
      formula = AsciiChem::Cml.parse(xml)
      expect(formula.nodes.select { |n| n.is_a?(AsciiChem::Model::OpaqueCml) }.length).to eq(1)
      re_emitted = formula.to_cml
      expect(re_emitted).to include("<experimentalNotes")
      expect(re_emitted).to include("Sample prepared under argon")
    end

    it "preserves multiple unknown elements at correct positions" do
      xml = <<~CML
        <?xml version="1.0"?>
        <cml xmlns="http://www.xml-cml.org/schema">
          <comment xmlns="http://x">start</comment>
          <molecule id="m1">
            <atomArray><atom id="a1" elementType="H"/></atomArray>
          </molecule>
          <comment xmlns="http://x">end</comment>
        </cml>
      CML
      formula = AsciiChem::Cml.parse(xml)
      opaques = formula.nodes.select { |n| n.is_a?(AsciiChem::Model::OpaqueCml) }
      expect(opaques.length).to eq(2)
      # OpaqueCml nodes should be at positions 0 and 2 (sandwiching the molecule)
      expect(formula.nodes[0]).to be_an(AsciiChem::Model::OpaqueCml)
      expect(formula.nodes[1]).to be_an(AsciiChem::Model::Molecule)
      expect(formula.nodes[2]).to be_an(AsciiChem::Model::OpaqueCml)
    end
  end

  describe "formatter integration" do
    let(:opaque) do
      AsciiChem::Model::OpaqueCml.new(element_name: "table", raw_xml: "<table/>")
    end

    it "Text formatter renders a warning comment" do
      expect(AsciiChem::Formatter.render(:text, opaque))
        .to eq("<!-- opaque: table -->")
    end

    it "HTML formatter renders a warning comment" do
      expect(AsciiChem::Formatter.render(:html, opaque))
        .to eq("<!-- opaque: table -->")
    end

    it "MathML formatter renders without raising" do
      expect { AsciiChem::Formatter.render(:mathml, opaque) }.not_to raise_error
    end

    it "LaTeX formatter renders a placeholder" do
      expect(AsciiChem::Formatter.render(:latex, opaque))
        .to eq("\\text{[opaque: table]}")
    end
  end
end
