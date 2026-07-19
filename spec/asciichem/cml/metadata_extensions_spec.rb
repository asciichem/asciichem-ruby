# frozen_string_literal: true

require "spec_helper"
require "chemicalml"
require "asciichem/cml"

RSpec.describe AsciiChem::Cml::MetadataExtensions do
  before(:all) { Chemicalml::Cml::Schema3.ensure_registered! }

  describe ".inject and .extract" do
    it "round-trips molecule metadata through XML" do
      formula = AsciiChem.parse('H_2O @meta("inchi","InChI=1/H2O/h1H2")')
      xml = AsciiChem::Cml.from_asciichem(formula)
      expect(xml).to include("aci:meta-inchi")
      expect(xml).to include("InChI=1/H2O/h1H2")

      parsed = AsciiChem::Cml.parse(xml)
      expect(parsed.nodes.first.metadata.length).to eq(1)
      meta = parsed.nodes.first.metadata.first
      expect(meta.name).to eq("inchi")
      expect(meta.content).to eq("InChI=1/H2O/h1H2")
    end

    it "is a no-op for molecules without metadata" do
      formula = AsciiChem.parse("H_2O")
      xml = AsciiChem::Cml.from_asciichem(formula)
      expect(xml).not_to include("aci:meta")
    end

    it "handles multiple metadata entries on one molecule" do
      formula = AsciiChem.parse('H_2O @meta("k1","v1") @meta("k2","v2")')
      xml = AsciiChem::Cml.from_asciichem(formula)
      expect(xml).to include("aci:meta-k1")
      expect(xml).to include("aci:meta-k2")
    end

    it "extracts metadata produced by another aci: producer" do
      xml = <<~CML
        <?xml version="1.0"?>
        <cml xmlns="http://www.xml-cml.org/schema" xmlns:aci="https://asciichem.org/cml-ext">
          <molecule id="m1" aci:meta-source="lab-A" aci:meta-date="2026-07-18">
            <atomArray><atom id="a1" elementType="H"/></atomArray>
          </molecule>
        </cml>
      CML
      meta_map = described_class.extract(xml)
      expect(meta_map["m1"]["source"]).to eq("lab-A")
      expect(meta_map["m1"]["date"]).to eq("2026-07-18")
    end
  end

  describe ".restore" do
    it "is a no-op when metadata_map is empty" do
      formula = AsciiChem.parse("H_2O")
      original = formula.nodes.dup
      described_class.restore(formula, {})
      expect(formula.nodes).to eq(original)
    end

    it "applies metadata to the matching molecule by index" do
      formula = AsciiChem.parse("H_2O")
      described_class.restore(formula, { "m1" => { "k" => "v" } })
      expect(formula.nodes.first.metadata.first.name).to eq("k")
      expect(formula.nodes.first.metadata.first.content).to eq("v")
    end
  end
end
