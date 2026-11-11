# frozen_string_literal: true

require "spec_helper"
require "asciichem/resolver"
require "tmpdir"

# Recorded-response transport (value fake).
CCFetch = Struct.new(:body) do
  def get(_url)
    body
  end
end

RSpec.describe AsciiChem::Resolver::CommonChemistry do
  let(:fixture) { File.read(File.expand_path("../../fixtures/resolver/common_chemistry/aspirin.json", __dir__)) }
  let(:fetch) { CCFetch.new(fixture) }
  let(:cache) { AsciiChem::Resolver::Cache.new(dir: File.join(Dir.tmpdir, "asciichem-cc-#{rand(1e9)}")) }

  it "self-registers (default-on per the maintainer decision of 2026-11-11)" do
    expect(AsciiChem::Resolver.adapters).to include("common_chemistry")
  end

  it "resolves by CAS RN" do
    substance = AsciiChem::Resolver.resolve(
      value: "50-78-2", convention: "cas", sources: [:common_chemistry],
      fetch: fetch, cache: cache)
    expect(substance.preferred_name).to eq("Aspirin")
    expect(substance.identifier_value("cas")).to eq("50-78-2")
    expect(substance.identifier_value("inchikey")).to eq("BSYNRYMUTXBXSQ-UHFFFAOYSA-N")
  end

  it "carries the CC BY-NC attribution on every identifier" do
    substance = described_class.new.resolve(value: "50-78-2", convention: "cas",
                                            fetch: fetch, cache: cache)
    expect(substance.identifiers.first.provenance.attribution)
      .to eq("CAS Common Chemistry (CC BY-NC 4.0)")
  end

  it "parses the structure from the source SMILES" do
    substance = described_class.new.resolve(value: "50-78-2", convention: "cas",
                                            fetch: fetch, cache: cache)
    expect(substance.structure.to_smiles).to eq("CC(=O)Oc1ccccc1C(=O)O")
  end

  it "queries the detail endpoint by CAS RN" do
    captured = []
    fetcher = Struct.new(:captured).new(captured)
    def fetcher.get(url)
      captured << url
      nil
    end
    described_class.new.resolve(value: "50-78-2", convention: "cas",
                                fetch: fetcher, cache: cache)
    expect(captured.last).to include("cas_rn=50-78-2")
  end
end

