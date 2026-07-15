# frozen_string_literal: true

require "spec_helper"
require "asciichem/cml"

RSpec.describe "ring closures (SMILES-style)" do
  describe "parser" do
    it "captures ring_closures on atom" do
      formula = AsciiChem.parse("C1-C1")
      atoms = formula.nodes.first.nodes.select { |n| n.is_a?(AsciiChem::Model::Atom) }
      expect(atoms.first.ring_closures).to eq("1")
      expect(atoms.last.ring_closures).to eq("1")
    end

    it "leaves ring_closures nil for atoms without closure" do
      formula = AsciiChem.parse("C1-C-C1")
      atoms = formula.nodes.first.nodes.select { |n| n.is_a?(AsciiChem::Model::Atom) }
      expect(atoms.first.ring_closures).to eq("1")
      expect(atoms[1].ring_closures).to be_nil
      expect(atoms.last.ring_closures).to eq("1")
    end

    it "supports multiple closures on one atom" do
      formula = AsciiChem.parse("C12-C-C1-C2")
      atoms = formula.nodes.first.nodes.select { |n| n.is_a?(AsciiChem::Model::Atom) }
      # First atom opens both ring 1 and ring 2 ("12")
      expect(atoms.first.ring_closures).to eq("12")
      # Last atom closes ring 2 only
      expect(atoms.last.ring_closures).to eq("2")
    end
  end

  describe "text round-trip" do
    cases = [
      "C1-C1",            # smallest ring (2 atoms)
      "C1-C-C1",          # 3-atom ring
      "C1-C-C-C-C-C1",    # cyclohexane (6-atom ring)
      "C12-C-C1-C2",      # two fused rings
      "C1-C2-C1-C2"       # two separate rings
    ]

    cases.each do |source|
      it "round-trips #{source.inspect} via Text formatter" do
        expect(AsciiChem.parse(source).to_text).to eq(source)
      end
    end
  end

  describe "CML round-trip" do
    cases = [
      "C1-C-C-C-C-C1",    # cyclohexane
      "C1-C-C1",          # 3-atom ring
      "C12-C-C1-C2"       # two fused rings
    ]

    cases.each do |source|
      it "round-trips #{source.inspect} through CML" do
        round_trip = AsciiChem::Cml.parse(AsciiChem.parse(source).to_cml).to_text
        expect(round_trip).to eq(source)
      end
    end

    it "emits a bond between ring closure atoms in CML" do
      xml = AsciiChem.parse("C1-C-C-C-C-C1").to_cml
      # 6 atoms + 6 bonds (5 positional + 1 ring closure)
      expect(xml.scan(/<atom /).length).to eq(6)
      expect(xml.scan(/<bond /).length).to eq(6)
      # The ring bond references a1 and a6
      expect(xml).to include('atomRefs2="a1 a6"')
    end

    it "carries ring_closures via aci:ringClosures attribute" do
      xml = AsciiChem.parse("C1-C-C-C-C-C1").to_cml
      expect(xml).to include('aci:ringClosures="1"')
    end
  end

  describe "RingBonds helper" do
    it "yields ring bond pairs" do
      formula = AsciiChem.parse("C1-C-C-C-C-C1")
      molecule = formula.nodes.first
      pairs = AsciiChem::RingBonds.to_enum(:each_in, molecule).to_a
      expect(pairs.length).to eq(1)
      expect(pairs.first.digit).to eq("1")
      expect(pairs.first.from_atom.element).to eq("C")
      expect(pairs.first.to_atom.element).to eq("C")
    end

    it "yields multiple pairs for fused rings" do
      formula = AsciiChem.parse("C12-C-C1-C2")
      molecule = formula.nodes.first
      pairs = AsciiChem::RingBonds.to_enum(:each_in, molecule).to_a
      expect(pairs.length).to eq(2)
      digits = pairs.map(&:digit).sort
      expect(digits).to eq(%w[1 2])
    end

    it "unclosed_atoms returns atoms with unmatched digits" do
      formula = AsciiChem.parse("C1-C-C")
      molecule = formula.nodes.first
      unclosed = AsciiChem::RingBonds.unclosed_atoms(molecule)
      expect(unclosed.length).to eq(1)
      expect(unclosed.first.ring_closures).to eq("1")
    end

    it "unclosed_atoms is empty for matched rings" do
      formula = AsciiChem.parse("C1-C-C-C-C-C1")
      molecule = formula.nodes.first
      expect(AsciiChem::RingBonds.unclosed_atoms(molecule)).to be_empty
    end
  end

  describe "UnclosedRingCheck linter" do
    it "errors on unmatched ring closure" do
      diagnostics = AsciiChem::Linter.run(AsciiChem.parse("C1-C-C"))
      errors = diagnostics.select { |d| d.severity == :error && d.message.include?("ring closure") }
      expect(errors.length).to be >= 1
    end

    it "passes for matched ring closures" do
      diagnostics = AsciiChem::Linter.run(AsciiChem.parse("C1-C-C-C-C-C1"))
      ring_errors = diagnostics.select { |d| d.message.include?("ring closure") }
      expect(ring_errors).to be_empty
    end
  end

  describe "structural SVG renders ring bonds" do
    it "includes the ring bond as an edge in the layout" do
      formula = AsciiChem.parse("C1-C-C-C-C-C1")
      result = AsciiChem::Layout.layout(formula.nodes.first)
      # 6 atoms, 6 bonds (including the ring closure)
      expect(result.atoms.length).to eq(6)
      expect(result.bonds.length).to eq(6)
    end
  end

  describe "ring closures inside groups" do
    cases = [
      "(C1-C-C-C-C-C1)",  # ring inside paren group
      "[C1-C-C1]",        # ring inside square group
      "{C1-C-C1}",        # ring inside brace group
      "Ca(C1-C-C1)",      # ring group embedded in molecule
      "((C1-C-C1))"       # nested group around ring
    ]

    cases.each do |source|
      it "round-trips #{source.inspect} through CML" do
        round_trip = AsciiChem::Cml.parse(AsciiChem.parse(source).to_cml).to_text
        expect(round_trip).to eq(source)
      end
    end

    it "preserves the group structure around the ring" do
      xml = AsciiChem.parse("(C1-C-C1)").to_cml
      formula = AsciiChem::Cml.parse(xml)
      molecule = formula.nodes.first
      # The molecule should contain a Group wrapping the ring chain
      group = molecule.nodes.first
      expect(group).to be_a(AsciiChem::Model::Group)
      # The group contains the full chain: atom, bond, atom, bond, atom
      expect(group.nodes.length).to eq(5)
      expect(group.nodes.first).to be_a(AsciiChem::Model::Atom)
      expect(group.nodes.first.ring_closures).to eq("1")
      expect(group.nodes.last).to be_a(AsciiChem::Model::Atom)
      expect(group.nodes.last.ring_closures).to eq("1")
    end
  end
end
