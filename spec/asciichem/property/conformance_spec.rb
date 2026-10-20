# frozen_string_literal: true

require 'spec_helper'

# Differential conformance (TODO.v2/13 item 5): generated models are
# canonicalized to text, re-parsed, and compared for equality. Every
# failure is a round-trip contract break — the corpus cannot cover
# what a generator can reach. Seeded for determinism; failures print
# the seed and the offending text.
RSpec.describe 'property-based round-trip conformance' do
  SEED = 20_261_020
  CASES = 300

  ELEMENTS = %w[H C N O F S P Cl].freeze
  BOND_KINDS = %i[single double single triple].freeze

  def rng
    @rng ||= Random.new(SEED)
  end

  def pick(list)
    list[rng.rand(list.length)]
  end

  # A random connected molecule: a chain skeleton with occasional
  # branches, ring-closure attempts (same-runner pairs), and stereo
  # annotations on a subset of atoms and single bonds.
  def generate_molecule
    size = 2 + rng.rand(6)
    atoms = Array.new(size) do
      AsciiChem::Model::Atom.new(
        element: pick(ELEMENTS),
        charge: pick([nil, nil, nil, '2+', '-']),
        chirality: pick([nil, nil, nil, nil, 'TH1', 'TH2'])
      )
    end
    bonds = (1...size).map do |_i|
      AsciiChem::Model::Bond.new(
        kind: pick(BOND_KINDS),
        direction: (pick([nil, nil, nil, :up, :down]) if rng.rand(6).zero?)
      )
    end
    # One ring-closure attempt between two non-adjacent atoms.
    bonds << AsciiChem::Model::Bond.new(kind: :single, direction: nil) if size >= 5 && rng.rand(3).zero?
    AsciiChem::Model::Molecule.new(nodes: atoms.zip(bonds).flatten.compact)
  end

  it "round-trips #{CASES} generated molecules through canonical text" do
    failures = []
    CASES.times do |i|
      molecule = generate_molecule
      text = molecule.to_text
      reparsed = AsciiChem.parse(text)
      failures << "seed #{SEED} case #{i}: #{text.inspect}" unless reparsed.nodes.first == molecule
    rescue AsciiChem::ParseError => e
      failures << "seed #{SEED} case #{i}: #{text.inspect} raised #{e.message[0, 60]}"
    end
    expect(failures).to be_empty, failures.first(5).join("\n")
  end

  it 'keeps seeded generation deterministic' do
    first = generate_molecule
    @rng = nil
    expect(generate_molecule.to_text).to eq(first.to_text)
  end
end
