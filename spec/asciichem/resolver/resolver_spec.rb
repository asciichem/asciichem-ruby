# frozen_string_literal: true

require "spec_helper"
require "asciichem/resolver"
require "tmpdir"

module ResolverSpec
  Fetch = Struct.new(:body) do
    def get(_url)
      body
    end
  end

  # Network access from an offline lookup would be a bug.
  OfflineFetch = Struct.new(nil) do
    def get(url) = raise("network must not be touched: #{url}")
  end

  # Builds a one-off fixture-backed source registered under `name`.
  def self.fixture_source(name, body)
    Class.new(AsciiChem::Resolver::Adapter) do
      source_name name
      supports "name"
      define_method(:fetch_record) do |value:, convention:, fetch:|
        props = JSON.parse(body).dig("PropertyTable", "Properties", 0)
        next nil unless props

        provenance = AsciiChem::Resolver::Provenance.new(source: name.to_s)
        AsciiChem::Resolver::Substance.new(
          preferred_name: props["IUPACName"],
          identifiers: [AsciiChem::Resolver::Identifier.new(
            value: props["InChIKey"], convention: "inchikey", provenance: provenance
          )]
        )
      end
    end
  end
end

RSpec.describe AsciiChem::Resolver do
  let(:fixture) { File.read(File.expand_path("../../fixtures/resolver/pubchem/aspirin.json", __dir__)) }
  let(:fetch) { ResolverSpec::Fetch.new(fixture) }
  let(:cache) { described_class::Cache.new(dir: File.join(Dir.tmpdir, "asciichem-spec-#{rand(1e9)}")) }

  it "resolves via the first answering source by default" do
    substance = described_class.resolve(value: "aspirin", convention: "name",
                                        fetch: fetch, cache: cache)
    expect(substance.provenance.source).to eq("pubchem")
  end

  it "returns one substance per answering source" do
    described_class.register(:spec_mirror, ResolverSpec.fixture_source(:spec_mirror, fixture))
    begin
      results = described_class.resolve_all(value: "aspirin", convention: "name",
                                            fetch: fetch, cache: cache)
      expect(results.map { |s| s.provenance.source }.sort).to eq(%w[pubchem spec_mirror])
    ensure
      described_class.adapters.delete("spec_mirror")
    end
  end

  it "raises Conflict when sources disagree on the InChIKey" do
    disagreement = fixture.gsub("BSYNRYMUTXBXSQ-UHFFFAOYSA-N", "WRONGKEY-WRONGWRONG-A")
    described_class.register(:spec_mirror, ResolverSpec.fixture_source(:spec_mirror, disagreement))
    begin
      expect {
        described_class.resolve!(value: "aspirin", convention: "name",
                                 fetch: fetch, cache: cache)
      }.to raise_error(described_class::Conflict, /disagree/)
    ensure
      described_class.adapters.delete("spec_mirror")
    end
  end

  it "caches resolution results in the user cache dir and serves them offline" do
    substance = described_class.resolve(value: "aspirin", convention: "name",
                                        fetch: fetch, cache: cache)
    expect(substance.identifier_value("inchikey")).to eq("BSYNRYMUTXBXSQ-UHFFFAOYSA-N")
    expect(Dir.exist?(cache.dir)).to be(true)

    cached = described_class.resolve(value: "aspirin", convention: "name",
                                     fetch: ResolverSpec::OfflineFetch.new, cache: cache)
    expect(cached.identifier_value("inchikey")).to eq("BSYNRYMUTXBXSQ-UHFFFAOYSA-N")

    fresh = described_class.resolve(value: "aspirin", convention: "name",
                                    fetch: fetch, cache: cache, refresh: true)
    expect(fresh.identifier_value("pubchem-cid")).to eq("2244")
  end

  it "serializes substance records to the canonical wire form" do
    substance = described_class.resolve(value: "aspirin", convention: "name",
                                        fetch: fetch, cache: cache)
    wire = JSON.parse(substance.to_model_json)
    expect(wire["type"]).to eq("substance-record")
    expect(wire["preferredName"]).to eq("2-acetyloxybenzoic acid")
    expect(wire["identifiers"].first.dig("identifier", "convention")).to eq("pubchem-cid")
    expect(wire.dig("identifiers", 0, "provenance", "source")).to eq("pubchem")
  end

  it "round-trips a substance through the wire form (cache path)" do
    substance = described_class.resolve(value: "aspirin", convention: "name",
                                        fetch: fetch, cache: cache)
    restored = described_class::Substance.from_model_json(substance.to_model_json)
    expect(restored.identifier_value("inchikey")).to eq(substance.identifier_value("inchikey"))
    expect(restored.preferred_name).to eq(substance.preferred_name)
  end

  it "raises an actionable error for unknown sources" do
    expect { described_class[:nope] }
      .to raise_error(AsciiChem::Error, /unknown resolver source/)
  end
end
