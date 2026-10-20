# frozen_string_literal: true

require 'spec_helper'

# Stereo slice (TODO.v2/14, corpus 0.5.0): SMILES chirality (@/@@ →
# Atom#chirality TH1/TH2) and directional bonds (/ \ → Bond#direction
# up/down). The strong property everywhere: parse → write → parse
# returns an equal model — the writer recomputes each atom's @/@@ for
# its own traversal order, so enantiomers stay distinct through the
# canonical form.
RSpec.describe 'SMILES stereo (L3 slice 1)' do
  subject(:smiles) { AsciiChem::Smiles }
  def round_trip_stable?(source)
    molecule = smiles.parse(source).nodes.first
    written = AsciiChem::Smiles::Writer.new(molecule).write
    reparsed = smiles.parse(written).nodes.first
    [written, reparsed == molecule]
  end

  describe 'tetrahedral chirality' do
    it 'stores @ as TH1 and @@ as TH2' do
      expect(smiles.parse('N[C@H](C)C(=O)O').nodes.first.nodes
        .find { |n| n.is_a?(AsciiChem::Model::Atom) && n.chirality }.chirality).to eq('TH1')
      expect(smiles.parse('N[C@@H](C)C(=O)O').nodes.first.nodes
        .find { |n| n.is_a?(AsciiChem::Model::Atom) && n.chirality }.chirality).to eq('TH2')
    end

    it 'round-trips both alanine enantiomers' do
      %w[N[C@@H](C)C(=O)O N[C@H](C)C(=O)O].each do |source|
        written, stable = round_trip_stable?(source)
        expect(stable).to be(true), "#{source} -> #{written} did not reparse equal"
      end
    end

    it 'keeps enantiomers distinct through the canonical form' do
      l = smiles.parse('N[C@@H](C)C(=O)O').nodes.first
      d = smiles.parse('N[C@H](C)C(=O)O').nodes.first
      expect(AsciiChem::Smiles::Writer.new(l).write)
        .not_to eq(AsciiChem::Smiles::Writer.new(d).write)
    end
  end

  describe 'directional bonds (E/Z)' do
    it 'stores / as up and \\ as down on the flanking single bonds' do
      molecule = smiles.parse('F/C=C/F').nodes.first
      directions = molecule.nodes.grep(AsciiChem::Model::Bond)
                           .filter_map(&:direction)
      expect(directions).to eq(%i[up up])
    end

    it 'round-trips both difluoroethene isomers' do
      ['F/C=C/F', 'F/C=C\\F'].each do |source|
        written, stable = round_trip_stable?(source)
        expect(stable).to be(true), "#{source} -> #{written} did not reparse equal"
      end
    end

    it 'keeps the isomers distinct through the canonical form' do
      e = smiles.parse('F/C=C/F').nodes.first
      z = smiles.parse('F/C=C\\F').nodes.first
      expect(AsciiChem::Smiles::Writer.new(e).write)
        .not_to eq(AsciiChem::Smiles::Writer.new(z).write)
    end
  end

  describe 'cyclic stereo (slice 3)' do
    # Ring-closure neighbours participate in the parity order: the
    # model's reference order lists them from the ring edges (the
    # correction handles the reordering, acyclic or not).
    it 'round-trips cyclic chirality' do
      ['C1[C@H](O)CCC1', 'C1[C@@H](O)CCC1'].each do |source|
        written, stable = round_trip_stable?(source)
        expect(stable).to be(true), "#{source} -> #{written} did not reparse equal"
      end
    end

    it 'keeps the cyclic enantiomers distinct through the canonical form' do
      a = smiles.parse('C1[C@H](O)CCC1').nodes.first
      b = smiles.parse('C1[C@@H](O)CCC1').nodes.first
      expect(AsciiChem::Smiles::Writer.new(a).write)
        .not_to eq(AsciiChem::Smiles::Writer.new(b).write)
    end
  end
end

RSpec.describe 'stereo on the wire (L3 slice 4)' do
  it 'carries chirality and direction through the wire round-trip' do
    %w[N[C@@H](C)C(=O)O F/C=C/F F/C=C\\F].each do |source|
      molecule = AsciiChem::Smiles.parse(source).nodes.first
      wire = AsciiChem::WireAdapter.to_wire(molecule)
      back = AsciiChem::WireAdapter.from_wire(wire)
      expect(back).to eq(molecule), "#{source} did not survive the wire"
    end
  end
end
