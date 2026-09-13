# frozen_string_literal: true

require "spec_helper"
require "asciichem/resolver"
require "relaton_bib"

RSpec.describe AsciiChem::Citation do
  let(:pubchem_fixture) { File.read(File.expand_path("../fixtures/resolver/pubchem/aspirin.json", __dir__)) }

  def aspirin_from(source_fixture, source)
    fetch = Struct.new(:body).new(source_fixture)
    def fetch.get(_url) = body
    adapter = AsciiChem::Resolver[source].new
    adapter.resolve(value: "50-78-2", convention: "cas",
                    fetch: fetch,
                    cache: AsciiChem::Resolver::Cache.new(dir: "/tmp/asciichem-cite-#{rand(1e9)}"))
  end

  it "builds a dataset-type bibitem from a resolved substance" do
    substance = aspirin_from(pubchem_fixture, :pubchem)
    item = described_class.bibitem(substance)
    expect(item).to be_a(RelatonBib::BibliographicItem)
    xml = item.to_xml
    expect(xml).to include('type="dataset"')
    expect(xml).to include("2-acetyloxybenzoic acid")
    expect(xml).to include("PubChem CID 2244")
    expect(xml).to include("https://pubchem.ncbi.nlm.nih.gov/compound/2244")
    expect(xml).to match(%r{<date type="accessed">})
  end

  it "carries every identifier as keywords for cross-checking" do
    substance = aspirin_from(pubchem_fixture, :pubchem)
    xml = described_class.to_xml(substance)
    expect(xml).to include("inchikey=BSYNRYMUTXBXSQ-UHFFFAOYSA-N")
    expect(xml).to include("canonical-smiles=CC(=O)OC1=CC=CC=C1C(=O)O")
  end

  it "cites Common Chemistry with its own profile and attribution" do
    cc_fixture = File.read(File.expand_path("../fixtures/resolver/common_chemistry/aspirin.json", __dir__))
    cc_fetch = Struct.new(:body).new(cc_fixture)
    def cc_fetch.get(_url) = body
    substance = AsciiChem::Resolver::CommonChemistry.new.resolve(
      value: "50-78-2", convention: "cas", fetch: cc_fetch,
      cache: AsciiChem::Resolver::Cache.new(dir: "/tmp/asciichem-cite-cc-#{rand(1e9)}"))
    xml = described_class.to_xml(substance)
    expect(xml).to include("CAS Common Chemistry")
    expect(xml).to include("CAS RN 50-78-2")
    expect(xml).to include("https://commonchemistry.cas.org/detail?cas_rn=50-78-2")
  end

  it "raises for substances without provenance" do
    bare = AsciiChem::Resolver::Substance.new(
      identifiers: [AsciiChem::Resolver::Identifier.new(value: "50-78-2", convention: "cas")]
    )
    expect { described_class.bibitem(bare) }
      .to raise_error(AsciiChem::Error, /no provenance/)
  end
end
