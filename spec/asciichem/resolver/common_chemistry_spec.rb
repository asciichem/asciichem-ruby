# frozen_string_literal: true

require 'spec_helper'
require 'asciichem/resolver'
require 'tmpdir'

# Recorded-response transport (value fake).
CCFetch = Struct.new(:body) do
  def get(_url, _headers = {})
    body
  end
end

RSpec.describe AsciiChem::Resolver::CommonChemistry do
  let(:fixture) { File.read(File.expand_path('../../fixtures/resolver/common_chemistry/aspirin.json', __dir__)) }
  let(:fetch) { CCFetch.new(fixture) }
  let(:cache) { AsciiChem::Resolver::Cache.new(dir: File.join(Dir.tmpdir, "asciichem-cc-#{rand(1e9)}")) }

  # Key-hermetic: specs run with no key unless one is explicitly
  # provided, whatever the developer's machine carries in the env or
  # the stored token file. Direct const swap — stub_const is barred
  # from around-style before hooks, and no doubles are involved.
  before do
    @key_file_original = described_class::KEY_FILE
    described_class.send(:remove_const, :KEY_FILE)
    described_class.const_set(:KEY_FILE, '/nonexistent')
    @key_env_original = ENV.delete('COMMON_CHEMISTRY_API_KEY')
  end

  after do
    described_class.send(:remove_const, :KEY_FILE)
    described_class.const_set(:KEY_FILE, @key_file_original)
    ENV['COMMON_CHEMISTRY_API_KEY'] = @key_env_original if @key_env_original
  end

  it 'self-registers (default-on per the maintainer decision of 2026-11-11)' do
    expect(AsciiChem::Resolver.adapters).to include('common_chemistry')
  end

  it 'resolves by CAS RN' do
    substance = AsciiChem::Resolver.resolve(
      value: '50-78-2', convention: 'cas', sources: [:common_chemistry],
      fetch: fetch, cache: cache
    )
    expect(substance.preferred_name).to eq('Aspirin')
    expect(substance.identifier_value('cas')).to eq('50-78-2')
    expect(substance.identifier_value('inchikey')).to eq('BSYNRYMUTXBXSQ-UHFFFAOYSA-N')
  end

  it 'carries the CC BY-NC attribution on every identifier' do
    substance = described_class.new.resolve(value: '50-78-2', convention: 'cas',
                                            fetch: fetch, cache: cache)
    expect(substance.identifiers.first.provenance.attribution)
      .to eq('CAS Common Chemistry (CC BY-NC 4.0)')
  end

  it 'parses the structure from the source SMILES' do
    substance = described_class.new.resolve(value: '50-78-2', convention: 'cas',
                                            fetch: fetch, cache: cache)
    expect(substance.structure.to_smiles).to eq('CC(=O)Oc1ccccc1C(=O)O')
  end

  def capturing_fetcher
    captured = []
    fetcher = Struct.new(:captured, :headers).new(captured, [])
    def fetcher.get(url, headers = {})
      captured << url
      self.headers << headers
      nil
    end
    fetcher
  end

  it 'queries the direct-api detail endpoint by CAS RN' do
    fetcher = capturing_fetcher
    described_class.new(api_key: nil).resolve(value: '50-78-2', convention: 'cas',
                                              fetch: fetcher, cache: cache)
    expect(fetcher.captured.last).to include('/direct-api/detail?cas_rn=50-78-2')
    expect(fetcher.captured.last).not_to include('apikey')
  end

  it 'sends the x-origin and accept headers on every request' do
    fetcher = capturing_fetcher
    described_class.new(api_key: nil).resolve(value: '50-78-2', convention: 'cas',
                                              fetch: fetcher, cache: cache)
    headers = fetcher.headers.last
    expect(headers['x-origin']).to eq('https://commonchemistry.cas.org/api-overview')
    expect(headers['Accept']).to eq('application/json')
  end

  it 'sends a user-provided key as the X-API-KEY header' do
    fetcher = capturing_fetcher
    described_class.new(api_key: 'cas-key-123').resolve(value: '50-78-2', convention: 'cas',
                                                        fetch: fetcher, cache: cache)
    expect(fetcher.headers.last['X-API-KEY']).to eq('cas-key-123')
  end

  it 'sends no X-API-KEY without a key' do
    fetcher = capturing_fetcher
    described_class.new(api_key: nil).resolve(value: '50-78-2', convention: 'cas',
                                              fetch: fetcher, cache: cache)
    expect(fetcher.headers.last).not_to have_key('X-API-KEY')
  end

  it 'picks the key up from COMMON_CHEMISTRY_API_KEY' do
    ENV['COMMON_CHEMISTRY_API_KEY'] = 'env-key-456'
    expect(described_class.new.api_key).to eq('env-key-456')
  end

  it 'falls back to the stored key file' do
    described_class.send(:remove_const, :KEY_FILE)
    described_class.const_set(:KEY_FILE,
                              File.expand_path('../../fixtures/resolver/common_chemistry/api.key', __dir__))
    expect(described_class.new.api_key).to eq('file-stored-token')
  end
end
