# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AsciiChem::Linter::IdentityCrossCheck do
  let(:stub_bin) { File.expand_path('../../fixtures/inchi/stub-inchi-1', __dir__) }
  let(:aspirin_inchi) { 'InChI=1S/C9H8O4/c1-6(10)13-8-5-3-2-4-7(8)9(11)12/h2-5H,1H3,(H,11,12)' }
  let(:aspirin_inchikey) { 'BSYNRYMUTXBXSQ-UHFFFAOYSA-N' }

  def aspirin_with(annotations)
    molecule = AsciiChem.parse_smiles('CC(=O)OC1=CC=CC=C1C(=O)O').nodes.first
    annotations.each do |convention, value|
      molecule.identifiers << AsciiChem::Model::Identifier.new(convention: convention, value: value)
    end
    AsciiChem::Model::Formula.new(nodes: [molecule])
  end

  def check(formula)
    described_class.new.run(formula)
  end

  around do |example|
    AsciiChem::Inchi.engine = nil
    example.run
    AsciiChem::Inchi.engine = nil
  end

  it 'auto-registers as :identity_cross_check' do
    expect(AsciiChem::Linter::Registry.names).to include(:identity_cross_check)
  end

  it 'stays silent when no identity annotations are present' do
    expect(check(AsciiChem.parse('H_2O'))).to be_empty
  end

  it 'warns once when molecules are annotated but no engine is configured' do
    diagnostics = check(aspirin_with([['inchi', aspirin_inchi]]))
    expect(diagnostics.length).to eq(1)
    expect(diagnostics.first.severity).to eq(:warning)
    expect(diagnostics.first.message).to include('no InChI engine configured')
  end

  it 'passes when the annotated InChI matches the drawn structure' do
    AsciiChem::Inchi.engine = AsciiChem::Inchi::BinaryEngine.new(bin: stub_bin)
    expect(check(aspirin_with([['inchi', aspirin_inchi], ['inchikey', aspirin_inchikey]]))).to be_empty
  end

  it 'errors when the annotated InChI contradicts the drawn structure' do
    AsciiChem::Inchi.engine = AsciiChem::Inchi::BinaryEngine.new(bin: stub_bin)
    wrong = 'InChI=1S/C9H8O4/c1-6(10)13-8-5-3-2-4-7(8)9(11)12/h2-4H,1H3,(H,11,12)'
    diagnostics = check(aspirin_with([['inchi', wrong]]))
    expect(diagnostics.length).to eq(1)
    expect(diagnostics.first.severity).to eq(:error)
    expect(diagnostics.first.message).to include('does not match the drawn structure')
    expect(diagnostics.first.message).to include("computed #{aspirin_inchi}")
  end

  it 'errors when the annotated InChIKey contradicts the drawn structure' do
    AsciiChem::Inchi.engine = AsciiChem::Inchi::BinaryEngine.new(bin: stub_bin)
    diagnostics = check(aspirin_with([%w[inchikey XLYOFNOQVPJJNP-UHFFFAOYSA-N]]))
    expect(diagnostics.length).to eq(1)
    expect(diagnostics.first.severity).to eq(:error)
    expect(diagnostics.first.message).to include("computed #{aspirin_inchikey}")
  end

  it 'warns instead of raising when the molecule is not a structure' do
    AsciiChem::Inchi.engine = AsciiChem::Inchi::BinaryEngine.new(bin: stub_bin)
    diagnostics = check(AsciiChem.parse("H_2O @inchi(\"#{aspirin_inchi}\")"))
    expect(diagnostics.length).to eq(1)
    expect(diagnostics.first.severity).to eq(:warning)
    expect(diagnostics.first.message).to include('cannot derive InChI')
  end
end

RSpec.describe AsciiChem::Linter::IdentityCrossCheck, "stereo assertions" do
  StereoEngine = Struct.new(:result) do
    def identity(_molecule)
      result
    end
  end

  def alanine_with_inchi(value)
    molecule = AsciiChem.parse_smiles("N[C@@H](C)C(=O)O").nodes.first
    molecule.identifiers << AsciiChem::Model::Identifier.new(convention: "inchi", value: value)
    AsciiChem::Model::Formula.new(nodes: [molecule])
  end

  around do |example|
    AsciiChem::Inchi.engine = nil
    example.run
    AsciiChem::Inchi.engine = nil
  end

  it "errors when the annotation differs only in the stereo layer" do
    annotated = "InChI=1S/C3H7NO2/c1-2(4)3(5)6/h2H,4H2,1H3,(H,5,6)/t2-/m0/s1"
    computed = "InChI=1S/C3H7NO2/c1-2(4)3(5)6/h2H,4H2,1H3,(H,5,6)/t2-/m1/s1"
    AsciiChem::Inchi.engine = StereoEngine.new(
      AsciiChem::Inchi::Identity.new(inchi: computed, inchikey: "QNAYBMKLOCPYGJ-UHFFFAOYSA-N")
    )

    diagnostics = described_class.new.run(alanine_with_inchi(annotated))
    expect(diagnostics.length).to eq(1)
    expect(diagnostics.first.severity).to eq(:error)
    expect(diagnostics.first.message).to include("does not match the drawn structure")
    expect(diagnostics.first.message).to include(computed)
  end

  it "stays silent when the stereo layers agree" do
    inchi = "InChI=1S/C3H7NO2/c1-2(4)3(5)6/h2H,4H2,1H3,(H,5,6)/t2-/m0/s1"
    AsciiChem::Inchi.engine = StereoEngine.new(
      AsciiChem::Inchi::Identity.new(inchi: inchi, inchikey: "QNAYBMKLOCPYGJ-UHFFFAOYSA-N")
    )

    expect(described_class.new.run(alanine_with_inchi(inchi))).to be_empty
  end
end
