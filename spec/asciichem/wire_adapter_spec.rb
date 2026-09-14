# frozen_string_literal: true

require "spec_helper"

RSpec.describe AsciiChem::WireAdapter do
  describe "canonical JSON round-trip" do
    [
      "H_2O",
      "^14C",
      "Ca^2+",
      "Ca^(II)",
      "::O",
      "N.",
      "(OH)_2",
      "[OH]_2",
      "{OH}_2",
      "H-O-H",
      "HC#CH",
      "2H_2 + O_2 -> 2H_2O",
      "N_2 + 3H_2 <=>[Fe][400°C] 2NH_3",
      "A -> B -> C",
      "1s^2 2s^2 2p^6",
      "`K_c = 1`",
      '"free text"',
      'H_2O @cas("7732-18-5")',
      "C1-C-C-C-C-C1",
      "(R)-C_2H_5OH",
      "(alpha)-C_6H_12O_6"
    ].each do |source|
      it "round-trips #{source.inspect}" do
        restored = described_class.from_model_json(AsciiChem.parse(source).to_model_json)
        expect(restored.to_text).to eq(source)
      end
    end
  end

  describe "emission" do
    it "emits the type discriminator on every node" do
      json = AsciiChem.parse("H_2O").to_model_json
      tree = JSON.parse(json)
      expect(tree["type"]).to eq("formula")
      expect(tree.dig("nodes", 0, "type")).to eq("molecule")
      expect(tree.dig("nodes", 0, "nodes", 0, "type")).to eq("atom")
    end

    it "emits the defining isotope binding (^14C)" do
      json = AsciiChem.parse("^14C").to_model_json
      atom = JSON.parse(json).dig("nodes", 0, "nodes", 0)
      expect(atom).to include("element" => "C", "isotope" => "14")
    end

    it "emits identifier annotations with their convention" do
      json = AsciiChem.parse('C @cas("74-82-8")').to_model_json
      identifier = JSON.parse(json).dig("nodes", 0, "identifiers", 0)
      expect(identifier).to include("type" => "identifier", "value" => "74-82-8", "convention" => "cas")
    end

    it "emits beyond-formulas nodes (mechanism/spectrum/crystal/zmatrix/calculation)" do
      expect(AsciiChem.parse("1s^2 2s^2").to_model_json).to include("electron-configuration")
      expect(AsciiChem.parse('"note: toxic"').to_model_json).to include('"text"')
    end

    it "raises for domain nodes without a wire form" do
      node = Class.new(AsciiChem::Model::Node)
      expect { described_class.to_wire(node.new) }.to raise_error(ArgumentError, /no wire form/)
    end
  end

  describe "ingestion guards" do
    it "raises for emission-only node types" do
      json = JSON.generate({ "type" => "formula", "nodes" => [{ "type" => "substance-record", "identifiers" => [] }] })
      expect { described_class.from_model_json(json) }.to raise_error(ArgumentError, /not implemented/)
    end

    it "raises for unknown discriminators" do
      expect { described_class.from_model_json('{"type":"warp-field"}') }.to raise_error(KeyError, /warp-field/)
    end

    it "raises for a missing discriminator" do
      expect { described_class.from_model_json('{"element":"C"}') }.to raise_error(KeyError, /type discriminator/)
    end
  end
end
