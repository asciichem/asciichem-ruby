# frozen_string_literal: true

require "spec_helper"

RSpec.describe AsciiChem::Smiles do
  describe ".parse" do
    it "parses a linear chain with single bonds" do
      formula = described_class.parse("CCO")
      molecule = formula.nodes.first
      expect(molecule.nodes.map(&:class)).to eq(
        [AsciiChem::Model::Atom, AsciiChem::Model::Bond,
         AsciiChem::Model::Atom, AsciiChem::Model::Bond,
         AsciiChem::Model::Atom]
      )
      expect(molecule.nodes.grep(AsciiChem::Model::Atom).map(&:element)).to eq(%w[C C O])
      expect(AsciiChem::Structure::Graph.build(molecule).last.map(&:kind)).to eq(%i[single single])
    end

    it "binds the prefix isotope like the AsciiChem parser does" do
      atom = described_class.parse("[13CH4]").nodes.first.nodes.first
      expect(atom.element).to eq("C")
      expect(atom.isotope).to eq("13")
      expect(atom.hydrogens).to eq(4)
    end

    it "maps bracket charges to the model's number-then-sign form" do
      expect(described_class.parse("[NH4+]").nodes.first.nodes.first.charge).to eq("+")
      expect(described_class.parse("[Fe++]").nodes.first.nodes.first.charge).to eq("2+")
      expect(described_class.parse("[O-2]").nodes.first.nodes.first.charge).to eq("2-")
    end

    it "parses aromatic rings with aromatic bonds" do
      molecule = described_class.parse("c1ccccc1").nodes.first
      atoms = molecule.nodes.grep(AsciiChem::Model::Atom)
      expect(atoms.map(&:aromatic)).to all(be true)
      expect(atoms.map(&:element)).to all(eq("C"))
      _atoms, edges = AsciiChem::Structure::Graph.build(molecule)
      expect(edges.length).to eq(6)
      expect(edges.map(&:kind)).to all(eq(:aromatic))
      expect(atoms.map(&:ring_closures).compact.length).to eq(2)
    end

    it "parses Kekulé benzene without aromatising it" do
      _atoms, edges = AsciiChem::Structure::Graph.build(
        described_class.parse("C1=CC=CC=C1").nodes.first
      )
      expect(edges.map(&:kind).sort).to eq(%i[double double double single single single])
    end

    it "parses branches" do
      _atoms, edges = AsciiChem::Structure::Graph.build(
        described_class.parse("C(C)C").nodes.first
      )
      expect(edges.length).to eq(2)
      expect(edges.map { |e| [e.from, e.to] }).to contain_exactly([0, 1], [0, 2])
    end

    it "parses dot-disconnected components as separate molecules" do
      formula = described_class.parse("O.CCO")
      expect(formula.nodes.length).to eq(2)
    end

    it "parses multi-digit %nn ring closures" do
      molecule = described_class.parse("C1CCCCCCCCCC1").nodes.first
      _atoms, edges = AsciiChem::Structure::Graph.build(molecule)
      expect(edges.length).to eq(11)
    end

    it "round-trips into AsciiChem text as a bonded structure" do
      expect(described_class.parse("CCO").to_text).to eq("C-C-O")
    end

    it "carries the new fields through the wire form" do
      wire = JSON.parse(described_class.parse("c1ccccc1").to_model_json)
      atom = wire["nodes"][0]["nodes"][0]
      expect(atom["aromatic"]).to be(true)
    end
  end

  describe "rejected input (v1 subset, actionable messages)" do
    it "rejects unclosed ring bonds" do
      expect { described_class.parse("C1CC") }
        .to raise_error(AsciiChem::ParseError, /unclosed ring bond/i)
    end

    # Stereo moved from the v1 rejections to supported features
    # (corpus 0.5.0): @/@@ parse into Atom#chirality (TH1/TH2) and
    # / \ into Bond#direction.
    it "rejects malformed chirality tokens" do
      expect { described_class.parse("[C@H") }
        .to raise_error(AsciiChem::ParseError)
    end

    it "rejects bonded ring closures the model cannot represent" do
      expect { described_class.parse("C=1CCCCC=1") }
        .to raise_error(AsciiChem::ParseError, /ring closure/i)
    end

    it "rejects trailing garbage" do
      expect { described_class.parse("CC!X") }
        .to raise_error(AsciiChem::ParseError, /unexpected character/)
    end
  end

  describe ".write" do
    it "round-trips simple canonical forms exactly" do
      %w[CCO CCC c1ccccc1 C1CCCCC1 [NH4+] [O-] [13CH4] N#N
         CC(=O)O C1=CCC(C)C(C)C1].each do |smiles|
        expect(described_class.parse(smiles).to_smiles).to eq(smiles)
      end
    end

    # Item 2: the canonicalizer consumes the perception pass —
    # Kekulé aromatic input converges on the lowercase spelling.
    it "canonicalizes perceived aromatic rings to the aromatic form" do
      {
        "C1=CC=CC=C1" => "c1ccccc1",
        "CC(=O)OC1=CC=CC=C1C(=O)O" => "CC(=O)Oc1ccccc1C(=O)O",
        "ClC1=CC=CC=C1" => "Clc1ccccc1",
        "C1=CC=NC=C1" => "c1ccncc1",
        "C1=CC=C2C=CC=CC2=C1" => "c1ccc2ccccc2c1",
        "C1=COC=C1" => "c1cocc1",
        "C1=CNC=C1" => "c1c[nH]cc1",
        "C1=CSC=C1" => "c1cscc1"
      }.each do |kekule, canonical|
        expect(described_class.parse(kekule).to_smiles).to eq(canonical)
        expect(described_class.parse(canonical).to_smiles).to eq(canonical)
      end
    end

    it "keeps quinones Kekulé (exocyclic double bonds are not aromatic)" do
      %w[O=C1C=CC=CC1 O=C1C=CC(=O)C=C1].each do |smiles|
        expect(described_class.parse(smiles).to_smiles).to eq(smiles)
      end
    end

    # #103: a closure-bearing child continues the chain, so the digit
    # lands at the end of the traversal instead of inside a branch and
    # the written atom order matches the model's.
    it "keeps ring-closure digits out of branches" do
      %w[C1=CCC(C)C(C)C1 C1CC2CCC1C2 C1CC(C)CCC1].each do |smiles|
        molecule = described_class.parse(smiles)
        written = molecule.to_smiles
        expect(written).to eq(smiles)
        expect(described_class.parse(written)).to eq(molecule)
      end
    end

    it "emits branches before the continuation, deterministically" do
      expect(described_class.parse("C(C)C").to_smiles).to eq("C(C)C")
    end

    it "joins formula components with dots" do
      expect(described_class.parse("O.CCO").to_smiles).to eq("O.CCO")
    end

    it "is stable under re-writing" do
      %w[CC(=O)OC1=CC=CC=C1C(=O)O CC(C)CC(C)C c1ccc2ccccc2c1].each do |smiles|
        once = described_class.parse(smiles).to_smiles
        twice = described_class.parse(once).to_smiles
        expect(twice).to eq(once)
      end
    end

    # Canonicalization maps many models to one spelling (Kekulé →
    # aromatic), so model equality is not the invariant — composition
    # and connectivity must survive, and the canonical form must be a
    # fixed point.
    it "preserves composition and connectivity through a write/parse cycle" do
      %w[CC(=O)OC1=CC=CC=C1C(=O)O c1ccc2ccccc2c1 CC(C)(C)C].each do |smiles|
        original = described_class.parse(smiles).nodes.first
        rewritten = described_class.parse(original.to_smiles).nodes.first
        expect(rewritten.element_counts).to eq(original.element_counts)
        before_atoms, before_edges =
          AsciiChem::Structure::Graph.build(original)
        after_atoms, after_edges = AsciiChem::Structure::Graph.build(rewritten)
        expect(after_atoms.length).to eq(before_atoms.length)
        expect(after_edges.length).to eq(before_edges.length)
        expect(rewritten.to_smiles).to eq(original.to_smiles)
      end
    end

    it "emits an explicit single bond between aromatic atoms" do
      expect(described_class.parse("c1ccccc1-c1ccccc1").to_smiles)
        .to eq("c1ccccc1-c2ccccc2")
    end

    it "raises for molecules without connectivity" do
      expect { AsciiChem.parse("H_2O").to_smiles }
        .to raise_error(AsciiChem::ParseError, /not a structure/i)
    end

    it "raises for AsciiChem-only bond kinds" do
      expect { AsciiChem.parse("C>-C").to_smiles }
        .to raise_error(AsciiChem::ParseError, /no SMILES form/i)
    end
  end
end
