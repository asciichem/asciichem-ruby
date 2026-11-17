# frozen_string_literal: true

require "asciichem"

RSpec.describe AsciiChem::Structure::Kekule do
  def aromatic_edges_for(smiles)
    molecule = AsciiChem::Smiles.parse(smiles).nodes.first
    _atoms, edges = AsciiChem::Structure::Graph.build(molecule)
    [molecule, edges]
  end

  describe ".bond_kinds" do
    it "assigns alternating kinds along the chain, closure single by grammar" do
      molecule, edges = aromatic_edges_for("c1ccccc1")

      kinds = described_class.bond_kinds(molecule)

      chain_kinds = edges.select { |edge| edge.bond }
                         .map { |edge| kinds[edge.bond] }
      expect(chain_kinds).to eq(%i[double single double single double])
      expect(edges.count { |edge| edge.kind == :aromatic }).to eq(6)
    end

    it "never touches the model — aromatic bonds stay aromatic" do
      molecule, edges = aromatic_edges_for("c1ccccc1")

      described_class.bond_kinds(molecule)

      expect(edges.map(&:kind)).to all(eq(:aromatic))
      expect(molecule.nodes.grep(AsciiChem::Model::Atom).map(&:aromatic)).to all(be true)
    end

    it "gives no projection for odd rings (the spec'd text loss)" do
      molecule, = aromatic_edges_for("c1ccoc1")

      expect(described_class.bond_kinds(molecule)).to be_empty
    end

    it "kekulizes fused systems that admit a Kekulé form" do
      molecule, edges = aromatic_edges_for("c1cc2ccccc2cc1")

      kinds = described_class.bond_kinds(molecule)
      expect(kinds).not_to be_empty

      chain_kinds = edges.select { |edge| edge.bond }
                         .map { |edge| kinds[edge.bond] }
      expect(chain_kinds).to include(:double, :single)
    end

    it "returns an empty projection for models without aromatic bonds" do
      molecule = AsciiChem.parse_smiles("C1CCCCC1").nodes.first

      expect(described_class.bond_kinds(molecule)).to be_empty
    end
  end

  describe "text projection round-trip" do
    it "renders benzene as re-parseable Kekulé text" do
      text = AsciiChem.parse_smiles("c1ccccc1").to_text

      expect(text).to eq("C1=C-C=C-C=C1")
      reparsed = AsciiChem.parse(text).nodes.first
      bonds = reparsed.nodes.grep(AsciiChem::Model::Bond)
      expect(bonds.count { |bond| bond.kind == :double }).to eq(3)
      expect(AsciiChem.parse(text).to_text).to eq(text)
    end

    it "renders pyridine as re-parseable Kekulé text" do
      text = AsciiChem.parse_smiles("c1ccncc1").to_text

      expect(text).to eq("C1=C-C=N-C=C1")
      reparsed = AsciiChem.parse(text).nodes.first
      bonds = reparsed.nodes.grep(AsciiChem::Model::Bond)
      expect(bonds.count { |bond| bond.kind == :double }).to eq(3)
      expect(AsciiChem.parse(text).to_text).to eq(text)
    end

    it "keeps the Kekulé spelling itself unchanged" do
      expect(AsciiChem.parse("C1=CC=CC=C1").to_text).to eq("C1=CC=CC=C1")
    end

    it "declines odd rings to the aromatic glyph" do
      expect(AsciiChem.parse_smiles("c1ccoc1").to_text).to eq("C1:C:C:O:C1")
    end
  end
end
