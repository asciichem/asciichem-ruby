# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AsciiChem::Layout do
  describe 'depiction algorithm' do
    def layout_of(source)
      molecule = AsciiChem.parse(source).nodes.first
      described_class.layout(molecule, algorithm: 'depiction')
    end

    def bond_lengths(result)
      by_id = result.atoms_by_id
      result.bonds.filter_map do |bond|
        from = by_id[bond.from_id]
        to = by_id[bond.to_id]
        Math.sqrt(((from.x - to.x)**2) + ((from.y - to.y)**2))
      end
    end

    it 'returns an empty result when the molecule has no atoms' do
      molecule = AsciiChem::Model::Molecule.new(nodes: [])
      result = described_class.layout(molecule, algorithm: 'depiction')
      expect(result.atoms).to be_empty
    end

    it 'places a benzene ring as a regular hexagon' do
      result = layout_of('C1-C-C-C-C-C1')
      expect(result.atoms.length).to eq(6)
      lengths = bond_lengths(result)
      expect(lengths).to all(be_within(0.01).of(lengths.first))
    end

    it 'places a four-ring as a square' do
      result = layout_of('C1-C-C-C1')
      lengths = bond_lengths(result)
      expect(lengths).to all(be_within(0.01).of(lengths.first))
    end

    it 'keeps every bond length equal to the standard bond length' do
      %w[C1-C-C-C-C-C1 C1-C-C-C1 C1-C-C-C-C-C-C1 C1-C-C-C-C-C12-C-C-C-C-C2-C1
         C-C1-C-C-C-C-C1].each do |source|
        expect(bond_lengths(layout_of(source))).to all(
          be_within(0.01).of(described_class::DepictionPlacer::BOND_LENGTH)
        )
      end
    end

    it 'fits fused rings without moving the shared atoms' do
      result = layout_of('C1-C-C-C2-C-C-C2-C1')
      lengths = bond_lengths(result)
      expect(lengths).to all(be_within(0.01).of(lengths.first))
    end

    it 'orients a spiro ring away from the placed ring' do
      result = layout_of('C1-C-C-C-C-C12-C-C-C-C-C2-C1')
      positions = result.atoms.map { |a| [a.x, a.y] }
      expect(positions.uniq.length).to eq(positions.length)
    end

    it 'grows substituents outward from the ring without overlaps' do
      result = layout_of('C-C1-C-C-C-C-C1')
      positions = result.atoms.map { |a| [a.x, a.y] }
      expect(positions.uniq.length).to eq(positions.length)
    end

    it 'zigzags a chain rather than curling it' do
      result = layout_of('C-C-C-C')
      xs = result.atoms.map(&:x)
      ys = result.atoms.map(&:y)
      expect(xs).to eq(xs.sort)
      expect(ys.uniq.length).to be >= 2
    end

    it 'never places two atoms at the same position' do
      %w[C-C-C C-C(-C)-C1-C-C-C-C-C1 C12-C-C1-C2].each do |source|
        result = layout_of(source)
        positions = result.atoms.map { |a| [a.x, a.y] }
        expect(positions.uniq.length).to eq(positions.length)
      end
    end

    it 'is deterministic across runs' do
      snapshots = 3.times.map do
        layout_of('C1-C-C-C2-C-C-C2-C1').atoms.map { |a| [a.id, a.x, a.y] }
      end
      expect(snapshots.uniq.length).to eq(1)
    end

    it 'carries charge through the depiction result' do
      molecule = AsciiChem.parse('O^- -C').nodes.first
      result = described_class.layout(molecule, algorithm: 'depiction')
      charged = result.atoms.find { |a| a.element == 'O' }
      expect(charged.charge).to eq('-')
    end

    it 'carries isotope through the depiction result' do
      molecule = AsciiChem.parse('^14C -C').nodes.first
      result = described_class.layout(molecule, algorithm: 'depiction')
      isotope = result.atoms.find { |a| a.element == 'C' && a.isotope }
      expect(isotope.isotope).to eq('14')
    end

    it 'keeps the default algorithm untouched by the placer' do
      molecule = AsciiChem.parse('C1-C-C-C-C-C1').nodes.first
      default_ids = described_class.layout(molecule).atoms.map(&:id)
      depiction_ids = described_class.layout(molecule, algorithm: 'depiction').atoms.map(&:id)
      expect(default_ids).to eq(depiction_ids)
    end
  end
end
