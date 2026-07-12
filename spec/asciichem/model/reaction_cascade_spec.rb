# frozen_string_literal: true

require "spec_helper"

RSpec.describe AsciiChem::Model::ReactionCascade do
  let(:atom_a) { AsciiChem::Model::Atom.new(element: "A") }
  let(:atom_b) { AsciiChem::Model::Atom.new(element: "B") }
  let(:atom_c) { AsciiChem::Model::Atom.new(element: "C") }
  let(:mol_a) { AsciiChem::Model::Molecule.new(nodes: [atom_a]) }
  let(:mol_b) { AsciiChem::Model::Molecule.new(nodes: [atom_b]) }
  let(:mol_c) { AsciiChem::Model::Molecule.new(nodes: [atom_c]) }

  let(:step1) { AsciiChem::Model::Reaction.new(reactants: [mol_a], products: [mol_b], arrow: :forward) }
  let(:step2) { AsciiChem::Model::Reaction.new(reactants: [mol_b], products: [mol_c], arrow: :forward) }

  describe "#initialize" do
    it "holds an ordered list of steps" do
      cascade = described_class.new(steps: [step1, step2])
      expect(cascade.steps).to eq([step1, step2])
    end
  end

  describe "#==" do
    it "compares steps" do
      a = described_class.new(steps: [step1, step2])
      b = described_class.new(steps: [step1, step2])
      expect(a).to eq(b)
    end
  end

  describe "parser integration" do
    it "parses a two-step cascade" do
      cascade = AsciiChem.parse("A -> B -> C").nodes.first
      expect(cascade).to be_a(described_class)
      expect(cascade.steps.size).to eq(2)
    end

    it "parses a three-step cascade" do
      cascade = AsciiChem.parse("A -> B -> C -> D").nodes.first
      expect(cascade.steps.size).to eq(3)
    end

    it "leaves a single reaction as Reaction, not Cascade" do
      node = AsciiChem.parse("A -> B").nodes.first
      expect(node).to be_a(AsciiChem::Model::Reaction)
      expect(node).not_to be_a(described_class)
    end

    it "supports mixed arrow kinds" do
      cascade = AsciiChem.parse("A <=>[Fe][T] B -> C").nodes.first
      expect(cascade.steps.first.arrow).to eq(:equilibrium)
      expect(cascade.steps.last.arrow).to eq(:forward)
    end
  end

  describe "round-trip" do
    it "round-trips a two-step cascade" do
      expect(AsciiChem.parse("A -> B -> C").to_text).to eq("A -> B -> C")
    end

    it "round-trips a three-step cascade" do
      expect(AsciiChem.parse("A -> B -> C -> D").to_text).to eq("A -> B -> C -> D")
    end

    it "round-trips a cascade with conditions" do
      expect(AsciiChem.parse("A <=>[Fe][T] B -> C").to_text).to eq("A <=>[Fe][T] B -> C")
    end
  end

  describe "formatters" do
    it "emits MathML with all steps in one mrow" do
      xml = AsciiChem.parse("A -> B -> C").to_mathml
      expect(xml).to include("→")
      expect(xml.scan("→").length).to eq(2)
    end

    it "emits HTML with arrows between terms" do
      html = AsciiChem.parse("A -> B -> C").to_html
      expect(html.scan("→").length).to eq(2)
    end

    it "emits LaTeX chain inside a single ce{}" do
      latex = AsciiChem.parse("A -> B -> C").to_latex
      expect(latex).to eq("\\ce{A -> B -> C}")
    end
  end
end
