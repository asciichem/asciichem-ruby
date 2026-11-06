# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AsciiChem::Inchi::NativeEngine do
  it 'documents the opt-in contract without a library' do
    expect { described_class.new(lib: nil) }
      .to raise_error(AsciiChem::Error, /CHEMOMER_LIB/)
  end

  it 'refuses an unreadable library path' do
    expect { described_class.new(lib: '/nonexistent/libchemomer.so') }
      .to raise_error(AsciiChem::Error, /not readable/)
  end

  # The real-library check mirrors the BinaryEngine's real-binary
  # spec: set CHEMOMER_LIB to the built cdylib (cargo build --release
  # in the chemomer checkout) to run it.
  lib = ENV.fetch('CHEMOMER_LIB', nil)
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

    it 'raises the engine error on a rejected molfile, not a null crash' do
      # An empty element writes an empty molfile element field; the
      # engine's reader rejects it and answers a null POINTER (truthy
      # as an FFI object) — the error path must nil?/null? it and
      # surface the engine's last_error as AsciiChem::Error.
      empty_element = AsciiChem::Model::Atom.new(element: '')
      formula = AsciiChem::Model::Formula.new(nodes: [empty_element])
      expect { engine.identity(formula) }
        .to raise_error(AsciiChem::Error, /chemomer native engine/)
    end
  end
end
