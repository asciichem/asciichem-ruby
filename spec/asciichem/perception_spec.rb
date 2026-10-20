# frozen_string_literal: true

require 'spec_helper'

# The perception pass (TODO.v2/13 item 2): chemistry the syntax
# leaves implicit, derived once and consumed everywhere.
RSpec.describe AsciiChem::Perception do
  def graph_for(smiles)
    molecule = AsciiChem::Smiles.parse(smiles).nodes.first
    AsciiChem::Structure::Graph.build(molecule)
  end

  describe 'implicit hydrogens' do
    def hydrogens_in(smiles, element, position = 0)
      atoms, edges = graph_for(smiles)
      picked = atoms.select { |a| a.element == element }[position]
      order = described_class.hydrogen_valence_sum(atoms.index(picked), edges)
      described_class.implicit_hydrogens(picked, order)
    end

    def all_hydrogens(smiles)
      atoms, edges = graph_for(smiles)
      atoms.each_with_index.map do |atom, index|
        described_class.implicit_hydrogens(
          atom, described_class.hydrogen_valence_sum(index, edges)
        )
      end
    end

    it 'gives bare methane carbon four implicit hydrogens' do
      expect(hydrogens_in('C', 'C')).to eq(4)
    end

    it 'gives ethanol oxygen one implicit hydrogen' do
      expect(hydrogens_in('CCO', 'O')).to eq(1)
    end

    it 'gives bare ammonia nitrogen three implicit hydrogens' do
      expect(hydrogens_in('N', 'N')).to eq(3)
    end

    it 'gives stated hydrogens zero implicit (never add to the source)' do
      expect(hydrogens_in('[NH4+]', 'N')).to eq(0)
    end

    it 'returns nil for charged atoms (charge algebra deferred)' do
      expect(hydrogens_in('[O-]', 'O')).to be_nil
    end

    it 'returns nil for elements without a valence table entry' do
      atoms, = graph_for('C')
      other = AsciiChem::Model::Atom.new(element: 'Xx')
      expect(described_class.implicit_hydrogens(other,
                                                described_class.bond_order_sum(atoms.index(atoms.first), []))).to be_nil
    end

    it 'perceives the same hydrogens for both spellings of benzene' do
      expect(all_hydrogens('C1=CC=CC=C1')).to eq(all_hydrogens('c1ccccc1'))
      expect(all_hydrogens('c1ccccc1')).to all(eq(1))
    end

    it 'gives pyridine nitrogen zero and its carbons one' do
      expect(all_hydrogens('c1ccncc1')).to eq([1, 1, 1, 0, 1, 1])
    end

    it 'declines on aromatic-schematic fusion atoms instead of inventing' do
      # Naphthalene's fusion carbons carry three aromatic bonds: the
      # Hückel sum 4.5 has no whole-number valence fit.
      expect(all_hydrogens('c1ccc2ccccc2c1')).to eq(
        [1, 1, 1, nil, 1, 1, 1, 1, nil, 1]
      )
    end
  end

  describe 'aromatic ring perception' do
    it 'perceives the Kekulé benzene ring' do
      atoms, edges = graph_for('C1=CC=CC=C1')
      rings = described_class.aromatic_rings(atoms, edges)
      expect(rings.length).to eq(1)
      expect(rings.first.length).to eq(6)
    end

    it 'perceives the aromatic-flag ring' do
      atoms, edges = graph_for('c1ccccc1')
      expect(described_class.aromatic_rings(atoms, edges).length).to eq(1)
    end

    it 'does not perceive plain cyclohexane' do
      atoms, edges = graph_for('C1CCCCC1')
      expect(described_class.aromatic_rings(atoms, edges)).to be_empty
    end

    it 'perceives both rings in naphthalene Kekulé form' do
      atoms, edges = graph_for('C1=CC=C2C=CC=CC2=C1')
      expect(described_class.aromatic_rings(atoms, edges).length).to eq(2)
    end
  end
end
