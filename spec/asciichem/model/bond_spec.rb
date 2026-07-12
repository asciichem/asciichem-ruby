# frozen_string_literal: true

require "spec_helper"

RSpec.describe AsciiChem::Model::Bond do
  describe "#initialize" do
    it "defaults to single bond" do
      expect(described_class.new.kind).to eq(:single)
    end
  end

  describe "#ascii" do
    it "maps kinds to ASCII spellings" do
      expect(described_class.new(kind: :single).ascii).to eq("-")
      expect(described_class.new(kind: :double).ascii).to eq("=")
      expect(described_class.new(kind: :triple).ascii).to eq("#")
      expect(described_class.new(kind: :quadruple).ascii).to eq("##")
      expect(described_class.new(kind: :wedge).ascii).to eq(">-")
      expect(described_class.new(kind: :hash).ascii).to eq("-<")
      expect(described_class.new(kind: :dative).ascii).to eq("~>")
      expect(described_class.new(kind: :wavy).ascii).to eq("~~")
    end
  end

  describe "#entity" do
    it "maps kinds to MathML entities" do
      expect(described_class.new(kind: :triple).entity).to eq("≡")
      expect(described_class.new(kind: :dative).entity).to eq("→")
    end
  end

  describe "all kind variants reachable via direct construction" do
    it "supports wedge, hash, dative, wavy kinds" do
      expect(described_class.new(kind: :wedge).kind).to eq(:wedge)
      expect(described_class.new(kind: :hash).kind).to eq(:hash)
      expect(described_class.new(kind: :dative).kind).to eq(:dative)
      expect(described_class.new(kind: :wavy).kind).to eq(:wavy)
    end

    it "maps every kind to an ASCII spelling" do
      described_class::KINDS.each_key do |kind|
        bond = described_class.new(kind: kind)
        expect(bond.ascii).to be_a(String)
        expect(bond.ascii.length).to be > 0
      end
    end

    it "maps every kind to a MathML entity" do
      described_class::KINDS.each_key do |kind|
        bond = described_class.new(kind: kind)
        expect(bond.entity).to be_a(String)
        expect(bond.entity.length).to be > 0
      end
    end
  end

  describe "parser integration" do
    it "parses single bonds in linear chains" do
      formula = AsciiChem.parse("H-O-H")
      molecule = formula.nodes.first
      expect(molecule.nodes.map(&:class).map(&:name)).to eq(%w[
        AsciiChem::Model::Atom
        AsciiChem::Model::Bond
        AsciiChem::Model::Atom
        AsciiChem::Model::Bond
        AsciiChem::Model::Atom
      ])
    end

    it "parses double bonds" do
      formula = AsciiChem.parse("H_2C=CH_2")
      bonds = formula.nodes.first.nodes.select { |n| n.is_a?(AsciiChem::Model::Bond) }
      expect(bonds.first.kind).to eq(:double)
    end

    it "parses triple bonds" do
      formula = AsciiChem.parse("HC#CH")
      bonds = formula.nodes.first.nodes.select { |n| n.is_a?(AsciiChem::Model::Bond) }
      expect(bonds.first.kind).to eq(:triple)
    end

    it "round-trips bonded molecules" do
      expect(AsciiChem.parse("H-O-H").to_text).to eq("H-O-H")
      expect(AsciiChem.parse("H_2C=CH_2").to_text).to eq("H_2C=CH_2")
    end
  end
end
