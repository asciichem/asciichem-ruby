# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AsciiChem::Inchi do
  let(:stub_bin) { File.expand_path('../fixtures/inchi/stub-inchi-1', __dir__) }
  let(:ethanol) { AsciiChem.parse_smiles('CCO').nodes.first }
  let(:ethanol_inchi) { 'InChI=1S/C2H6O/c1-2-3/h3H,2H2,1H3' }
  let(:ethanol_inchikey) { 'LFQSCWFLJHTTHZ-UHFFFAOYSA-N' }

  after { described_class.engine = nil }

  describe '.identity_for' do
    it 'raises EngineMissingError with install guidance when no engine is configured' do
      expect { described_class.identity_for(ethanol) }
        .to raise_error(AsciiChem::EngineMissingError, /install the IUPAC InChI software/)
    end

    it 'derives identity through the configured engine' do
      described_class.engine = AsciiChem::Inchi::BinaryEngine.new(bin: stub_bin)
      identity = described_class.identity_for(ethanol)
      expect(identity.inchi).to eq(ethanol_inchi)
      expect(identity.inchikey).to eq(ethanol_inchikey)
    end

    it 'prefers an engine passed per call over the configured one' do
      described_class.engine = AsciiChem::Inchi::BinaryEngine.new(bin: 'not-a-binary-xyz')
      identity = described_class.identity_for(ethanol, engine: AsciiChem::Inchi::BinaryEngine.new(bin: stub_bin))
      expect(identity.inchi).to eq(ethanol_inchi)
    end
  end
end

RSpec.describe AsciiChem::Inchi::BinaryEngine do
  let(:stub_bin) { File.expand_path('../fixtures/inchi/stub-inchi-1', __dir__) }
  let(:engine) { described_class.new(bin: stub_bin) }
  let(:ethanol) { AsciiChem.parse_smiles('CCO').nodes.first }
  let(:aspirin) { AsciiChem.parse_smiles('CC(=O)OC1=CC=CC=C1C(=O)O').nodes.first }

  it 'pipes the molecule through a molfile into the engine' do
    identity = engine.identity(aspirin)
    expect(identity.inchi).to eq('InChI=1S/C9H8O4/c1-6(10)13-8-5-3-2-4-7(8)9(11)12/h2-5H,1H3,(H,11,12)')
    expect(identity.inchikey).to eq('BSYNRYMUTXBXSQ-UHFFFAOYSA-N')
  end

  it 'implements the TODO.v2 10 engine interface' do
    expect(engine.to_inchi(ethanol)).to eq('InChI=1S/C2H6O/c1-2-3/h3H,2H2,1H3')
    expect(engine.to_inchikey(ethanol)).to eq('LFQSCWFLJHTTHZ-UHFFFAOYSA-N')
  end

  it 'raises EngineMissingError when the binary is not installed' do
    missing = described_class.new(bin: 'definitely-not-a-real-inchi-binary')
    expect { missing.identity(ethanol) }
      .to raise_error(AsciiChem::EngineMissingError, /definitely-not-a-real-inchi-binary.*not found/)
  end

  it 'raises when the engine exits non-zero' do
    benzene = AsciiChem.parse_smiles('c1ccccc1').nodes.first
    expect { engine.identity(benzene) }
      .to raise_error(AsciiChem::Error, /failed \(exit 1\)/)
  end

  it 'raises when the engine emits no InChI' do
    banner_only = File.expand_path('../fixtures/inchi/stub-inchi-1-banner-only', __dir__)
    expect { described_class.new(bin: banner_only).identity(ethanol) }
      .to raise_error(AsciiChem::Error, /produced no InChI/)
  end
end
