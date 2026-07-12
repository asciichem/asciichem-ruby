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
end
