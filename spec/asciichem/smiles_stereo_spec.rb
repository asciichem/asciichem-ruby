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

  describe 'known limitations (slice 3 closes)' do
    it 'leaves ring-closure neighbours uncorrected in the parity order' do
      # Chiral atoms whose reference order includes ring-closure
      # neighbours emit the stored token uncorrected — documented,
      # spec'd, closed by the canonical-stereo slice.
      written, stable = round_trip_stable?('C1[C@H](O)CCC1')
      expect(stable).to eq(written.include?('@'))
    end
  end
end
