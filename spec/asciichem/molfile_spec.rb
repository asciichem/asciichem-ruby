# frozen_string_literal: true

require "spec_helper"

RSpec.describe AsciiChem::Molfile do
  def atom_line(x, y, z, sym)
    format("%10.4f%10.4f%10.4f %-3s 0  0  0  0  0  0  0  0  0  0  0  0", x, y, z, sym)
  end

  def bond_line(a, b, type, stereo = 0)
    format("%3d%3d%3d%3d  0  0  0  0  0  0  0", a, b, type, stereo)
  end

  def counts_line(atoms, bonds)
    format("%3d%3d  0  0  0  0  0  0  0  0999 V2000", atoms, bonds)
  end

  def molfile(name, atom_lines, bond_lines, properties = [])
    ([name, "  AsciiChem", "", counts_line(atom_lines.length, bond_lines.length)] +
      atom_lines + bond_lines + properties + ["M  END"]).join("\n") << "\n"
  end

  let(:ethanol_molfile) do
    molfile("ethanol",
            [atom_line(-0.2500, 0.3750, 0.0, "C"),
             atom_line(0.4645, -0.0375, 0.0, "C"),
             atom_line(1.1790, 0.3750, 0.0, "O")],
            [bond_line(1, 2, 1), bond_line(2, 3, 1)])
  end

  let(:benzene_molfile) do
    molfile("benzene",
            [atom_line(-0.5000, 0.8660, 0.0, "C"),
             atom_line(0.5000, 0.8660, 0.0, "C"),
             atom_line(1.0000, 0.0000, 0.0, "C"),
             atom_line(0.5000, -0.8660, 0.0, "C"),
             atom_line(-0.5000, -0.8660, 0.0, "C"),
             atom_line(-1.0000, 0.0000, 0.0, "C")],
            [bond_line(1, 2, 4), bond_line(2, 3, 4), bond_line(3, 4, 4),
             bond_line(4, 5, 4), bond_line(5, 6, 4), bond_line(6, 1, 4)])
  end

  let(:ammonium_molfile) do
    molfile("ammonium",
            [atom_line(0.0000, 0.0000, 0.0, "N"),
             atom_line(0.9500, 0.0000, 0.0, "H"),
             atom_line(-0.4750, 0.8228, 0.0, "H"),
             atom_line(-0.4750, -0.8228, 0.0, "H"),
             atom_line(0.0000, 0.0000, 0.9500, "H")],
            [bond_line(1, 2, 1), bond_line(1, 3, 1), bond_line(1, 4, 1),
             bond_line(1, 5, 1)],
            ["M  CHG  1   1   1"])
  end

  describe ".parse" do
    it "parses atoms with coordinates and bonds" do
      molecule = described_class.parse(ethanol_molfile)
      atoms = molecule.nodes.grep(AsciiChem::Model::Atom)
      expect(atoms.map(&:element)).to eq(%w[C C O])
      expect(atoms.first.x2).to eq(-0.25)
      expect(atoms.first.y2).to eq(0.375)
      _atoms, edges = AsciiChem::Structure::Graph.build(molecule)
      expect(edges.length).to eq(2)
      expect(edges.map(&:kind)).to eq(%i[single single])
    end

    it "parses aromatic bond types" do
      _atoms, edges = AsciiChem::Structure::Graph.build(
        described_class.parse(benzene_molfile)
      )
      expect(edges.map(&:kind)).to all(eq(:aromatic))
      expect(edges.length).to eq(6)
    end

    it "parses M  CHG charges" do
      molecule = described_class.parse(ammonium_molfile)
      expect(molecule.nodes.first.charge).to eq("+")
    end

    it "parses wedges and hashes from bond stereo codes" do
      molfile = ethanol_molfile.sub("1  2  1  0", "1  2  1  1")
      _atoms, edges = AsciiChem::Structure::Graph.build(described_class.parse(molfile))
      expect(edges.first.kind).to eq(:wedge)
    end

    it "rejects truncated atom blocks" do
      broken = ethanol_molfile.lines.take(5).join
      expect { described_class.parse(broken) }
        .to raise_error(AsciiChem::ParseError, /truncated atom block/i)
    end

    it "rejects a missing counts line" do
      expect { described_class.parse("not\na\nmolfile\n") }
        .to raise_error(AsciiChem::ParseError)
    end
  end

  describe ".write" do
    it "round-trips through parse/write/parse preserving structure" do
      source = AsciiChem.parse_smiles("CCO").nodes.first
      written = described_class.write(source, name: "ethanol")
      reparsed = described_class.parse(written)

      expect(reparsed.nodes.grep(AsciiChem::Model::Atom).map(&:element)).to eq(%w[C C O])
      _a, edges = AsciiChem::Structure::Graph.build(reparsed)
      expect(edges.map(&:kind)).to eq(%i[single single])
      expect(written).to include("M  END")
      expect(written.lines[0]).to eq("ethanol\n")
    end

    it "round-trips charges and aromatic bonds" do
      ammonium = described_class.parse(ammonium_molfile)
      written = described_class.write(ammonium)
      expect(written).to include("M  CHG  1   1   1")
      reparsed = described_class.parse(written)
      expect(reparsed.nodes.first.charge).to eq("+")

      benzene = described_class.parse(benzene_molfile)
      _atoms, edges = AsciiChem::Structure::Graph.build(
        described_class.parse(described_class.write(benzene))
      )
      expect(edges.map(&:kind)).to all(eq(:aromatic))
    end

    it "uses authored coordinates verbatim" do
      source = described_class.parse(ethanol_molfile)
      written = described_class.write(source)
      expect(written).to include("-0.2500")
    end

    it "computes coordinates when the model has none" do
      source = AsciiChem.parse_smiles("C1CCCCC1").nodes.first
      written = described_class.write(source)
      expect(written.lines[4]).to match(/\A\s+-?\d+\.\d{4}/)
    end

    it "raises for formula-only molecules" do
      expect { described_class.write(AsciiChem.parse("H_2O").nodes.first) }
        .to raise_error(AsciiChem::ParseError, /not a structure/i)
    end
  end
end

RSpec.describe "molfile stereo (L3 slice 6)" do
  subject(:molfile) { AsciiChem::Molfile }
  let(:smiles) { AsciiChem::Smiles }

  it "emits tetrahedral chirality as the MDL atom parity field" do
    molecule = smiles.parse("N[C@@H](C)C(=O)O").nodes.first
    text = molfile.write(molecule)
    chiral_line = text.lines[5] # atom 2, the [C@@H]
    expect(chiral_line[31, 3].strip).to eq("C")
    expect(chiral_line[39, 3].to_i).to eq(2)
  end

  it "round-trips both alanine enantiomers through molfile" do
    %w[N[C@@H](C)C(=O)O N[C@H](C)C(=O)O].each do |source|
      molecule = smiles.parse(source).nodes.first
      restored = molfile.parse(molfile.write(molecule))
      expect(restored.to_smiles).to eq(source)
    end
  end

  it "keeps enantiomers distinct after the molfile leg" do
    first = smiles.parse("N[C@@H](C)C(=O)O").nodes.first
    second = smiles.parse("N[C@H](C)C(=O)O").nodes.first
    restored = molfile.parse(molfile.write(first))
    expect(restored.to_smiles).not_to eq(molfile.parse(molfile.write(second)).to_smiles)
  end

  it "carries stated hydrogens through the H-count field" do
    molecule = smiles.parse("C[CH3]").nodes.first
    restored = molfile.parse(molfile.write(molecule))
    methyl = restored.nodes.find { |n| n.is_a?(AsciiChem::Model::Atom) && n.element == "C" && n.hydrogens }
    expect(methyl.hydrogens).to eq(3)
  end

  it "documents the V2000 directional-bond loss (E/Z)" do
    # V2000 encodes E/Z through coordinates + double-bond stereo
    # codes, not single-bond direction flags: the model's
    # Bond#direction is not representable without stereo-aware
    # geometry. The loss is asserted, not silent.
    molecule = smiles.parse("F/C=C/F").nodes.first
    restored = molfile.parse(molfile.write(molecule))
    expect(restored.to_smiles).to eq("FC=CF")
  end
end

RSpec.describe 'Structure::Graph.build! (structure writers)' do
  def build(kind, source)
    molecule = (kind == :smiles ? AsciiChem.parse_smiles(source) : AsciiChem.parse(source)).nodes.first
    AsciiChem::Structure::Graph.build!(molecule)
  end

  it 'accepts fully bonded SMILES models across branch boundaries' do
    atoms, edges = build(:smiles, 'CC(=O)O')
    expect(atoms.map(&:element)).to eq(%w[C C O O])
    expect(edges.length).to eq(3)
  end

  it 'treats an explicit salt as separate single-atom components' do
    molecules = AsciiChem.parse_smiles('[Na+].[Cl-]').nodes
    expect(molecules.length).to eq(2)
    molecules.each do |molecule|
      atoms, edges = AsciiChem::Structure::Graph.build!(molecule)
      expect(atoms.length).to eq(1)
      expect(edges).to be_empty
    end
  end

  it 'declines formula-style adjacency instead of fragmenting silently' do
    expect { build(:text, 'CCO') }
      .to raise_error(AsciiChem::ParseError, /adjacent atoms have no explicit bond token/)
  end

  it 'declines undashed mixtures that would silently lose ring bonds' do
    # C1=CC=CC=C1 carries only its double bonds + one ring closure as
    # explicit tokens; the undashed spacers would fragment the ring.
    expect { build(:text, 'C1=CC=CC=C1') }
      .to raise_error(AsciiChem::ParseError, /adjacent atoms have no explicit bond token/)
  end

  it 'keeps the tolerant build usable for the linter' do
    molecule = AsciiChem.parse('CCO').nodes.first
    atoms, edges = AsciiChem::Structure::Graph.build(molecule)
    expect(atoms.length).to eq(3)
    expect(edges).to be_empty
  end
end
