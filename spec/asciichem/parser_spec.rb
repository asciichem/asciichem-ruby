# frozen_string_literal: true

require "spec_helper"

RSpec.describe AsciiChem::Parser do
  describe ".parse (via AsciiChem.parse)" do
    subject(:formula) { AsciiChem.parse(source) }

    context "with a single atom" do
      let(:source) { "He" }

      it "builds a Formula wrapping one Molecule wrapping one Atom" do
        expect(formula).to be_a(AsciiChem::Model::Formula)
        expect(formula.nodes.size).to eq(1)
        molecule = formula.nodes.first
        expect(molecule).to be_a(AsciiChem::Model::Molecule)
        atom = molecule.nodes.first
        expect(atom.element).to eq("He")
      end
    end

    context "with a subscripted molecule H_2O" do
      let(:source) { "H_2O" }

      it "binds the subscript to the preceding atom" do
        molecule = formula.nodes.first
        h, o = molecule.nodes
        expect(h.element).to eq("H")
        expect(h.subscript).to eq("2")
        expect(o.element).to eq("O")
        expect(o.subscript).to be_nil
      end
    end

    context "with a prefix isotope ^14C — the semantic fix" do
      let(:source) { "^14C" }

      it "binds the isotope to the atom, not to a phantom carrier" do
        atom = formula.nodes.first.nodes.first
        expect(atom.element).to eq("C")
        expect(atom.isotope).to eq("14")
        expect(atom.subscript).to be_nil
      end
    end

    context "with a suffix charge Ca^2+" do
      let(:source) { "Ca^2+" }

      it "captures the charge in atom.charge" do
        atom = formula.nodes.first.nodes.first
        expect(atom.element).to eq("Ca")
        expect(atom.charge).to eq("2+")
      end
    end

    context "with a coefficient 2H_2O" do
      let(:source) { "2H_2O" }

      it "attaches the coefficient to the molecule" do
        molecule = formula.nodes.first
        expect(molecule.coefficient).to eq("2")
      end
    end

    context "with a group Ca(OH)_2" do
      let(:source) { "Ca(OH)_2" }

      it "parses a group with multiplicity" do
        molecule = formula.nodes.first
        ca, group = molecule.nodes
        expect(ca.element).to eq("Ca")
        expect(group).to be_a(AsciiChem::Model::Group)
        expect(group.multiplicity).to eq("2")
        expect(group.bracket).to eq(:paren)
        expect(group.nodes.first.nodes.map(&:element)).to eq(%w[O H])
      end
    end

    context "with a forward reaction" do
      let(:source) { "2H_2 + O_2 -> 2H_2O" }

      it "builds a Reaction with two reactants and one product" do
        reaction = formula.nodes.first
        expect(reaction).to be_a(AsciiChem::Model::Reaction)
        expect(reaction.reactants.size).to eq(2)
        expect(reaction.products.size).to eq(1)
        expect(reaction.arrow).to eq(:forward)
      end
    end

    context "with an equilibrium arrow with conditions" do
      let(:source) { "N_2 + 3H_2 <=>[Fe][400°C] 2NH_3" }

      it "captures above and below conditions" do
        reaction = formula.nodes.first
        expect(reaction.arrow).to eq(:equilibrium)
        expect(reaction.conditions.above).to eq("Fe")
        expect(reaction.conditions.below).to eq("400°C")
      end
    end

    context "with whitespace-only input" do
      let(:source) { "   " }

      it "raises ParseError — the grammar requires at least one node" do
        expect { formula }.to raise_error(AsciiChem::ParseError)
      end
    end
  end
end
