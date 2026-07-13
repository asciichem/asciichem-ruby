# frozen_string_literal: true

require "spec_helper"
require "asciichem/cml"

RSpec.describe AsciiChem::Cml do
  describe ".from_asciichem (AsciiChem -> CML)" do
    it "converts a simple molecule" do
      formula = AsciiChem.parse("H_2O")
      xml = described_class.from_asciichem(formula)
      expect(xml).to include("<molecule")
      expect(xml).to include('elementType="H"')
      expect(xml).to include('elementType="O"')
      expect(xml).to include('count="2"')
    end

    it "converts an isotope" do
      formula = AsciiChem.parse("^14C")
      xml = described_class.from_asciichem(formula)
      expect(xml).to include('elementType="C"')
      expect(xml).to include('isotope="14"')
    end

    it "converts a charged atom" do
      formula = AsciiChem.parse("Ca^2+")
      xml = described_class.from_asciichem(formula)
      expect(xml).to include('elementType="Ca"')
      expect(xml).to include('formalCharge="2+"')
    end

    it "converts a reaction" do
      formula = AsciiChem.parse("2H_2 + O_2 -> 2H_2O")
      xml = described_class.from_asciichem(formula)
      expect(xml).to include("<reaction")
      expect(xml).to include("<reactantList>")
      expect(xml).to include("<productList>")
    end
  end

  describe ".parse (CML -> AsciiChem)" do
    it "round-trips a simple molecule" do
      original = AsciiChem.parse("H_2O")
      cml = described_class.from_asciichem(original)
      re_parsed = described_class.parse(cml)

      re_molecule = re_parsed.nodes.first
      expect(re_molecule).to be_a(AsciiChem::Model::Molecule)
      atoms = re_molecule.nodes.select { |n| n.is_a?(AsciiChem::Model::Atom) }
      expect(atoms.map(&:element)).to include("H", "O")
    end

    it "round-trips an isotope" do
      cml = AsciiChem.parse("^14C").to_cml
      re_parsed = described_class.parse(cml)
      atom = re_parsed.nodes.first.nodes.first
      expect(atom.element).to eq("C")
      expect(atom.isotope).to eq("14")
    end

    it "round-trips a reaction" do
      original = AsciiChem.parse("H_2 + O_2 -> H_2O")
      cml = described_class.from_asciichem(original)
      re_parsed = described_class.parse(cml)
      reaction = re_parsed.nodes.find { |n| n.is_a?(AsciiChem::Model::Reaction) }
      expect(reaction).not_to be_nil
      expect(reaction.reactants.length).to eq(2)
      expect(reaction.products.length).to eq(1)
    end
  end

  describe "Formula#to_cml convenience method" do
    it "is reachable from any Formula" do
      formula = AsciiChem.parse("H_2O")
      expect(formula.to_cml).to include("<cml")
    end
  end
end
