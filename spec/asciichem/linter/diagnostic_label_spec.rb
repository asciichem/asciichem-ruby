# frozen_string_literal: true

require "spec_helper"

RSpec.describe AsciiChem::Model::Node do
  describe "#diagnostic_label" do
    it "labels an Atom with its element" do
      atom = AsciiChem::Model::Atom.new(element: "C")
      expect(atom.diagnostic_label).to eq("Atom(C)")
    end

    it "labels a Molecule generically" do
      mol = AsciiChem::Model::Molecule.new(nodes: [])
      expect(mol.diagnostic_label).to eq("Molecule")
    end

    it "labels a Reaction generically" do
      rxn = AsciiChem::Model::Reaction.new(
        reactants: [AsciiChem::Model::Molecule.new(nodes: [])],
        products: []
      )
      expect(rxn.diagnostic_label).to eq("Reaction")
    end

    it "labels a Group generically" do
      group = AsciiChem::Model::Group.new(nodes: [])
      expect(group.diagnostic_label).to eq("Group")
    end

    it "labels a ReactionCascade generically" do
      cascade = AsciiChem::Model::ReactionCascade.new(steps: [])
      expect(cascade.diagnostic_label).to eq("Reaction Cascade")
    end

    it "labels an ElectronConfiguration generically" do
      ec = AsciiChem::Model::ElectronConfiguration.new(orbitals: [["1s", "2"]])
      expect(ec.diagnostic_label).to eq("Electron Configuration")
    end
  end
end

RSpec.describe AsciiChem::Linter::Diagnostic do
  describe "#to_s" do
    it "includes the atom context for atom diagnostics" do
      atom = AsciiChem::Model::Atom.new(element: "C")
      diag = described_class.new(severity: :error, message: "bad", node: atom)
      expect(diag.to_s).to eq("[error] Atom(C): bad")
    end

    it "omits context when there is no node" do
      diag = described_class.new(severity: :info, message: "hello", node: nil)
      expect(diag.to_s).to eq("[info] hello")
    end

    it "uses the model-driven label for any node type" do
      mol = AsciiChem::Model::Molecule.new(nodes: [])
      diag = described_class.new(severity: :warning, message: "missing", node: mol)
      expect(diag.to_s).to eq("[warning] Molecule: missing")
    end
  end
end
