# frozen_string_literal: true

require "spec_helper"

RSpec.describe AsciiChem::Model::Molecule do
  describe "#initialize" do
    it "holds nodes" do
      h = AsciiChem::Model::Atom.new(element: "H", subscript: "2")
      o = AsciiChem::Model::Atom.new(element: "O")
      mol = described_class.new(nodes: [h, o])
      expect(mol.nodes).to eq([h, o])
    end

    it "defaults coefficient to nil" do
      mol = described_class.new(nodes: [])
      expect(mol.coefficient).to be_nil
    end
  end

  describe "#==" do
    it "compares nodes and coefficient" do
      h = AsciiChem::Model::Atom.new(element: "H")
      a = described_class.new(nodes: [h], coefficient: "2")
      b = described_class.new(nodes: [h], coefficient: "2")
      expect(a).to eq(b)
    end
  end

  describe "#element_counts" do
    it "counts braced subscripts" do
      molecule = AsciiChem.parse("H_{2}O").nodes.first
      expect(molecule.element_counts).to eq("H" => 2, "O" => 1)
      expect(molecule.atom_count).to eq(3)
      expect(molecule.hill_formula).to eq("H2O")
    end
  end
end
