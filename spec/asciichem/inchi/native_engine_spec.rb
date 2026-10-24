# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AsciiChem::Inchi::NativeEngine do
  it 'documents the opt-in contract without a library' do
    expect { described_class.new(lib: nil) }
      .to raise_error(AsciiChem::Error, /INCHI_RS_LIB/)
  end

  it 'refuses an unreadable library path' do
    expect { described_class.new(lib: '/nonexistent/libinchi_rs.so') }
      .to raise_error(AsciiChem::Error, /not readable/)
  end

  # The real-library check mirrors the BinaryEngine's real-binary
  # spec: set INCHI_RS_LIB to the built cdylib (cargo build --release
  # in the inchi-rs checkout) to run it.
  lib = ENV.fetch('INCHI_RS_LIB', nil)
  next unless lib

  describe 'against a built cdylib' do
    let(:engine) { described_class.new(lib: lib) }
    let(:molecule) { AsciiChem.parse_smiles('CC(=O)O').nodes.first }

    it 'derives the recorded identity of acetic acid' do
      identity = engine.identity(molecule)
      expect(identity.inchi)
        .to eq('InChI=1S/C2H4O2/c1-2(3)4/h1H3,(H,3,4)')
      expect(identity.inchikey).to eq('QTBSBXVTEAMEQO-UHFFFAOYSA-N')
    end
  end
end
