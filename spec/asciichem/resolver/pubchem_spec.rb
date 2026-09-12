# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "asciichem/resolver"

# Lightweight recorded-response transport (Struct — the house rule
# against doubles applies to mocks, not value fakes carrying data).
RecordedFetch = Struct.new(:body) do
  def get(_url)
    body
  end
end

RSpec.describe AsciiChem::Resolver::PubChem do
  let(:fixture) { File.read(File.expand_path("../../fixtures/resolver/pubchem/aspirin.json", __dir__)) }
  let(:adapter) { described_class.new }

  it "registers itself as the pubchem source" do
    expect(AsciiChem::Resolver.adapters).to include("pubchem" => described_class)
  end

  it "supports the documented identifier conventions" do
    %w[name cas inchikey pubchem-cid].each do |convention|
      expect(adapter.supports?(convention)).to be(true), convention
    end
  end

  it "resolves aspirin by name from the recorded response" do
    substance = adapter.resolve(value: "aspirin", convention: "name",
                                fetch: RecordedFetch.new(fixture),
                                cache: null_cache)
    expect(substance.preferred_name).to eq("2-acetyloxybenzoic acid")
    expect(substance.formula).to eq("C9H8O4")
    expect(substance.molecular_weight).to eq(180.16)
    expect(substance.identifier_value("inchikey")).to eq("BSYNRYMUTXBXSQ-UHFFFAOYSA-N")
    expect(substance.identifier_value("pubchem-cid")).to eq("2244")
  end

  it "carries provenance with source and attribution on every identifier" do
    substance = adapter.resolve(value: "aspirin", convention: "name",
                                fetch: RecordedFetch.new(fixture),
                                cache: null_cache)
    provenance = substance.identifiers.first.provenance
    expect(provenance.source).to eq("pubchem")
    expect(provenance.attribution).to eq("PubChem, U.S. National Library of Medicine")
    expect(provenance.retrieved_at).to match(/\A\d{4}-\d{2}-\d{2}T/)
  end

  it "parses the structure when the SMILES is in the supported subset" do
    substance = adapter.resolve(value: "aspirin", convention: "name",
                                fetch: RecordedFetch.new(fixture),
                                cache: null_cache)
    expect(substance.structure).to be_a(AsciiChem::Model::Molecule)
    expect(substance.structure.to_smiles).to eq("CC(=O)OC1=CC=CC=C1C(=O)O")
  end

  it "keeps the SMILES as an identifier when it is outside the subset" do
    stereo = fixture.gsub("CC(=O)OC1=CC=CC=C1C(=O)O", "C[C@H](N)C(=O)O")
    substance = adapter.resolve(value: "aspirin", convention: "name",
                                fetch: RecordedFetch.new(stereo),
                                cache: null_cache)
    expect(substance.structure).to be_nil
    expect(substance.identifier_value("canonical-smiles")).to eq("C[C@H](N)C(=O)O")
  end

  it "returns nil for a not-found response (unknown substance)" do
    empty = RecordedFetch.new(nil)
    expect(adapter.resolve(value: "nonsense-xyz", convention: "name",
                           fetch: empty, cache: null_cache)).to be_nil
  end

  it "builds PUG-REST URLs per convention (CAS via the name namespace)" do
    captured = []
    adapter.resolve(value: "50-78-2", convention: "cas",
                    fetch: CaptureFetch.new(captured), cache: null_cache)
    expect(captured.last).to include("/compound/name/50-78-2/property/")
  end

  def null_cache
    AsciiChem::Resolver::Cache.new(dir: File.join(Dir.tmpdir, "asciichem-null-#{rand(1e9)}"))
  end
end

# Captures requested URLs; returns no body (not-found).
CaptureFetch = Struct.new(:captured) do
  def get(url)
    captured << url
    nil
  end
end
