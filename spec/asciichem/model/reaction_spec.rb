# frozen_string_literal: true

require "spec_helper"

RSpec.describe AsciiChem::Model::Reaction do
  let(:hydrogen) { AsciiChem::Model::Molecule.new(nodes: [AsciiChem::Model::Atom.new(element: "H", subscript: "2")]) }
  let(:oxygen)   { AsciiChem::Model::Molecule.new(nodes: [AsciiChem::Model::Atom.new(element: "O", subscript: "2")]) }
  let(:water)    { AsciiChem::Model::Molecule.new(nodes: [AsciiChem::Model::Atom.new(element: "H", subscript: "2"), AsciiChem::Model::Atom.new(element: "O")]) }

  describe "#arrow_ascii" do
    it "maps :forward to ->" do
      r = described_class.new(reactants: [hydrogen], products: [water], arrow: :forward)
      expect(r.arrow_ascii).to eq("->")
    end

    it "maps :equilibrium to <=>" do
      r = described_class.new(reactants: [hydrogen], products: [water], arrow: :equilibrium)
      expect(r.arrow_ascii).to eq("<=>")
    end
  end

  describe "#arrow_entity" do
    it "returns the unicode arrow for MathML" do
      r = described_class.new(reactants: [hydrogen], products: [water], arrow: :forward)
      expect(r.arrow_entity).to eq("→")
    end
  end

  describe "conditions" do
    it "builds with above and below" do
      conds = AsciiChem::Model::Reaction::Conditions.new(above: "Fe", below: "400°C")
      expect(conds.above).to eq("Fe")
      expect(conds.below).to eq("400°C")
    end
  end
end
