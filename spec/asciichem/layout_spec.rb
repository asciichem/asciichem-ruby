# frozen_string_literal: true

require "spec_helper"

RSpec.describe AsciiChem::Layout do
  describe ".layout" do
    it "returns an empty result when the molecule has no atoms" do
      molecule = AsciiChem::Model::Molecule.new(nodes: [])
      result = described_class.layout(molecule)
      expect(result.atoms).to be_empty
      expect(result.bonds).to be_empty
    end

    it "returns atoms without bonds when the molecule has no bonds" do
      molecule = AsciiChem.parse("H_2O").nodes.first
      result = described_class.layout(molecule)
      expect(result.atoms.length).to eq(2)
      expect(result.bonds).to be_empty
    end

    it "assigns stable IDs across runs of the same input" do
      mol1 = AsciiChem.parse("H-O-H").nodes.first
      mol2 = AsciiChem.parse("H-O-H").nodes.first
      ids1 = described_class.layout(mol1).atoms.map(&:id)
      ids2 = described_class.layout(mol2).atoms.map(&:id)
      expect(ids1).to eq(ids2)
      expect(ids1).to eq(%w[a1 a2 a3])
    end

    it "produces bonds that reference laid-out atom IDs" do
      molecule = AsciiChem.parse("H-O-H").nodes.first
      result = described_class.layout(molecule)
      bond_refs = result.bonds.map { |b| [b.from_id, b.to_id] }
      expect(bond_refs).to contain_exactly(%w[a1 a2], %w[a2 a3])
    end

    it "walks through Groups to find all atoms" do
      molecule = AsciiChem.parse("(H-O)-H").nodes.first
      result = described_class.layout(molecule)
      elements = result.atoms.map(&:element)
      expect(elements).to eq(%w[H O H])
    end

    it "preserves bond kind through layout" do
      molecule = AsciiChem.parse("H-O-H").nodes.first
      result = described_class.layout(molecule)
      expect(result.bonds.map(&:kind)).to all(eq(:single))
    end

    it "preserves atom charge through layout" do
      molecule = AsciiChem.parse("Ca^2+").nodes.first
      result = described_class.layout(molecule)
      expect(result.atoms.first.charge).to eq("2+")
    end

    it "preserves isotope through layout" do
      molecule = AsciiChem.parse("^14C").nodes.first
      result = described_class.layout(molecule)
      expect(result.atoms.first.isotope).to eq("14")
    end

    it "returns a result with positive width and height" do
      molecule = AsciiChem.parse("H-O-H").nodes.first
      result = described_class.layout(molecule)
      expect(result.width).to be > 0
      expect(result.height).to be > 0
    end
  end

  describe "Layout::Result" do
    it "indexes atoms by id" do
      molecule = AsciiChem.parse("H-O-H").nodes.first
      result = described_class.layout(molecule)
      expect(result.atoms_by_id.keys).to contain_exactly("a1", "a2", "a3")
      expect(result.atoms_by_id["a2"].element).to eq("O")
    end

    it "reports empty when atoms list is empty" do
      molecule = AsciiChem::Model::Molecule.new(nodes: [])
      result = described_class.layout(molecule)
      expect(result).to be_empty
    end
  end

  describe "authored coordinates (the depiction-hint override)" do
    it "overrides the computed layout when every atom carries x2/y2" do
      molecule = AsciiChem.parse("H-O-H").nodes.first
      atoms = molecule.nodes.grep(AsciiChem::Model::Atom)
      atoms.each_with_index do |atom, index|
        atom.x2 = 10.0 + index * 7
        atom.y2 = 20.0 - index * 3
      end
      result = described_class.layout(molecule)
      # The pre-positioned rule speaks the authored geometry verbatim
      # (the CML x2/y2 round-trip posture): no placer ran.
      expect(result.atoms.map { |a| [a.x, a.y] }).to eq(
        [[10.0, 20.0], [17.0, 17.0], [24.0, 14.0]]
      )
    end

    it "layouts normally when only some atoms carry coordinates" do
      molecule = AsciiChem.parse("H-O-H").nodes.first
      first = molecule.nodes.grep(AsciiChem::Model::Atom).first
      first.x2 = 10.0
      first.y2 = 20.0
      result = described_class.layout(molecule)
      # The partial authoring is ignored: the layout computed.
      expect(result.atoms.first.x).not_to eq(10.0)
    end
  end
end
