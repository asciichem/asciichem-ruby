# frozen_string_literal: true

require "spec_helper"
require "asciichem/cml"

# CML integration tests. Currently pending because the chemicalml gem
# has been refactored with a Schema3 namespace. The asciichem translator
# needs to be updated to match the new API surface.
RSpec.describe AsciiChem::Cml do
  describe ".from_asciichem (AsciiChem -> CML)" do
    pending "chemicalml Schema3 API realignment needed" do
      formula = AsciiChem.parse("H_2O")
      xml = described_class.from_asciichem(formula)
      expect(xml).to include("<molecule")
      expect(xml).to include('elementType="H"')
    end

    pending "chemicalml Schema3 API realignment needed" do
      formula = AsciiChem.parse("^14C")
      xml = described_class.from_asciichem(formula)
      expect(xml).to include('isotope="14"')
    end

    pending "chemicalml Schema3 API realignment needed" do
      formula = AsciiChem.parse("Ca^2+")
      xml = described_class.from_asciichem(formula)
      expect(xml).to include('formalCharge="2+"')
    end

    pending "chemicalml Schema3 API realignment needed" do
      formula = AsciiChem.parse("2H_2 + O_2 -> 2H_2O")
      xml = described_class.from_asciichem(formula)
      expect(xml).to include("<reaction")
    end
  end

  describe ".parse (CML -> AsciiChem)" do
    pending "chemicalml Schema3 API realignment needed" do
      original = AsciiChem.parse("H_2O")
      cml = described_class.from_asciichem(original)
      re_parsed = described_class.parse(cml)
      re_molecule = re_parsed.nodes.first
      expect(re_molecule).to be_a(AsciiChem::Model::Molecule)
    end

    pending "chemicalml Schema3 API realignment needed" do
      cml = AsciiChem.parse("^14C").to_cml
      re_parsed = described_class.parse(cml)
      atom = re_parsed.nodes.first.nodes.first
      expect(atom.element).to eq("C")
    end

    pending "chemicalml Schema3 API realignment needed" do
      original = AsciiChem.parse("H_2 + O_2 -> H_2O")
      cml = described_class.from_asciichem(original)
      re_parsed = described_class.parse(cml)
      reaction = re_parsed.nodes.find { |n| n.is_a?(AsciiChem::Model::Reaction) }
      expect(reaction).not_to be_nil
    end
  end

  describe "Formula#to_cml convenience method" do
    pending "chemicalml Schema3 API realignment needed" do
      formula = AsciiChem.parse("H_2O")
      expect(formula.to_cml).to include("<cml")
    end
  end
end
