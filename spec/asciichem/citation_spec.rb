# frozen_string_literal: true

require 'spec_helper'
require 'asciichem/citation'

RSpec.describe AsciiChem::Citation do
  let(:pubchem_fixture) { File.read(File.expand_path('../fixtures/resolver/pubchem/aspirin.json', __dir__)) }

  def aspirin_from(source_fixture, source)
    fetch = Struct.new(:body).new(source_fixture)
    def fetch.get(_url) = body
    adapter = AsciiChem::Resolver[source].new
    adapter.resolve(value: '50-78-2', convention: 'cas',
                    fetch: fetch,
                    cache: AsciiChem::Resolver::Cache.new(dir: "/tmp/asciichem-cite-#{rand(1e9)}"))
  end

  it 'builds a dataset-type bibitem from a resolved substance' do
    substance = aspirin_from(pubchem_fixture, :pubchem)
    xml = described_class.to_xml(substance)
    expect(xml).to include('type="dataset"')
    expect(xml).to include('2-acetyloxybenzoic acid')
    expect(xml).to include('PubChem CID 2244')
    expect(xml).to include('https://pubchem.ncbi.nlm.nih.gov/compound/2244')
    expect(xml).to match(/<date type="accessed">/)
  end

  it 'carries every identifier as keywords for cross-checking' do
    substance = aspirin_from(pubchem_fixture, :pubchem)
    xml = described_class.to_xml(substance)
    expect(xml).to include('inchikey=BSYNRYMUTXBXSQ-UHFFFAOYSA-N')
    expect(xml).to include('canonical-smiles=CC(=O)OC1=CC=CC=C1C(=O)O')
  end

  it 'cites Common Chemistry with its own profile and attribution' do
    cc_fixture = File.read(File.expand_path('../fixtures/resolver/common_chemistry/aspirin.json', __dir__))
    cc_fetch = Struct.new(:body).new(cc_fixture)
    def cc_fetch.get(_url) = body
    substance = AsciiChem::Resolver::CommonChemistry.new.resolve(
      value: '50-78-2', convention: 'cas', fetch: cc_fetch,
      cache: AsciiChem::Resolver::Cache.new(dir: "/tmp/asciichem-cite-cc-#{rand(1e9)}")
    )
    xml = described_class.to_xml(substance)
    expect(xml).to include('CAS Common Chemistry')
    expect(xml).to include('CAS RN 50-78-2')
    expect(xml).to include('https://commonchemistry.cas.org/detail?cas_rn=50-78-2')
  end

  it 'raises for substances without provenance' do
    bare = AsciiChem::Resolver::Substance.new(
      identifiers: [AsciiChem::Resolver::Identifier.new(value: '50-78-2', convention: 'cas')]
    )
    expect { described_class.bibitem(bare) }
      .to raise_error(AsciiChem::Error, /no provenance/)
  end

  describe '.for_molecule (the cite syntax)' do
    let(:cache) { AsciiChem::Resolver::Cache.new(dir: "/tmp/asciichem-cite-syntax-#{rand(1e9)}") }
    let(:fetch) do
      Struct.new(:body).new(File.read(File.expand_path('../fixtures/resolver/pubchem/aspirin.json', __dir__)))
    end

    def seeded_fetch(body)
      Struct.new(:body).new(body)
    end

    it 'parses @cite as a property annotation and round-trips it (zero grammar change)' do
      molecule = AsciiChem.parse('H_2O @name("water") @cite("pubchem")').nodes.first
      expect(molecule.to_text).to eq('H_2O @name("water") @cite("pubchem")')
      expect(molecule.properties.last.title).to eq('cite')
      expect(molecule.properties.last.value).to eq('pubchem')
    end

    it 'resolves and emits one bibitem per cited source' do
      body = File.read(File.expand_path('../fixtures/resolver/pubchem/aspirin.json', __dir__))
      fetcher = seeded_fetch(body)
      def fetcher.get(_url) = body
      molecule = AsciiChem.parse('H_2O @name("aspirin") @cite("pubchem")').nodes.first
      pairs = described_class.for_molecule(molecule, cache: cache, fetch: fetcher)
      expect(pairs.length).to eq(1)
      source, item = pairs.first
      expect(source).to eq('pubchem')
      expect(item.to_xml).to include('PubChem CID 2244')
    end

    it 'prefers registry identifiers over names for lookup' do
      captured = []
      fetcher = Struct.new(:captured) do
        def get(url)
          captured << url
          nil
        end
      end.new(captured)
      molecule = AsciiChem.parse('H_2O @cas("50-78-2") @name("x") @cite("pubchem")').nodes.first
      described_class.for_molecule(molecule, cache: cache, fetch: fetcher)
      expect(captured.last).to include('/compound/name/50-78-2/')
    end

    it 'returns [] when there are no @cite annotations' do
      molecule = AsciiChem.parse('H_2O @cas("50-78-2")').nodes.first
      expect(described_class.for_molecule(molecule)).to eq([])
    end

    it 'raises an actionable error when nothing identifies the molecule' do
      molecule = AsciiChem.parse('H_2O @cite("pubchem")').nodes.first
      expect { described_class.for_molecule(molecule) }
        .to raise_error(AsciiChem::Error, /no resolvable identifier/i)
    end
  end
end
