# frozen_string_literal: true

require 'spec_helper'
require 'asciichem/resolver'

RSpec.describe AsciiChem::Resolver::Opsin do
  let(:adapter) { described_class.new }

  # Recorded OPSIN response body for "2,3-dimethylbutane" — the
  # service answers with the derived SMILES as the whole body.
  let(:body) { "CC(C)C(C)\n" }

  it 'registers itself as the opsin source' do
    expect(AsciiChem::Resolver.adapters).to include('opsin' => described_class)
  end

  it 'supports the name conventions it derives from' do
    expect(adapter.supports?('iupac-name')).to be(true)
    expect(adapter.supports?('name')).to be(true)
    expect(adapter.supports?('cas')).to be(false)
  end

  it 'derives the structure from a systematic IUPAC name' do
    substance = adapter.resolve(value: '2,3-dimethylbutane', convention: 'iupac-name',
                                fetch: RecordedFetch.new(body),
                                cache: null_cache)
    expect(substance.structure).to be_a(AsciiChem::Model::Molecule)
    expect(substance.identifier_value('canonical-smiles')).to eq('CC(C)C(C)')
  end

  it 'attributes the Cambridge Centre for Molecular Informatics' do
    substance = adapter.resolve(value: '2,3-dimethylbutane', convention: 'name',
                                fetch: RecordedFetch.new(body),
                                cache: null_cache)
    expect(substance.identifiers.first.provenance.source).to eq('opsin')
    expect(substance.identifiers.first.provenance.attribution)
      .to include('University of Cambridge')
  end

  it 'keeps the SMILES as an identifier when the derived structure is outside the subset' do
    substance = adapter.resolve(value: 'something exotic', convention: 'name',
                                fetch: RecordedFetch.new("C[*]C\n"),
                                cache: null_cache)
    expect(substance.structure).to be_nil
    expect(substance.identifier_value('canonical-smiles')).to include('[*]')
  end
end
