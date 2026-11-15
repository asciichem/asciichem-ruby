# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AsciiChem::Rinchi::NativeEngine do
  it 'documents the opt-in contract without a library' do
    expect { described_class.new(lib: nil) }
      .to raise_error(AsciiChem::Error, /CHEMOMER_LIB/)
  end

  it 'refuses an unreadable library path' do
    expect { described_class.new(lib: '/nonexistent/libchemomer.so') }
      .to raise_error(AsciiChem::Error, /not readable/)
  end

  # The real-library check mirrors the Inchi::NativeEngine's
  # real-library spec: set CHEMOMER_LIB to the built cdylib (cargo
  # build --release in the chemomer checkout) to run it.
  lib = ENV.fetch('CHEMOMER_LIB', nil)
  next unless lib

  # The corpus's water-is-water RXNfile (inchi-tests v0.3.41): one
  # water drawn each side — the five oracle lines and the decode
  # table pin the transport byte-exactly.
  water_rxn = <<~RXN
    $RXN
    water-is-water
      chemomer recording

      1  1
    $MOL

      AsciiChem

      1  0  0  0  0  0  0  0  0  0999 V2000
       12.0000   12.0000    0.0000 O   0  0  0  0  0  0  0  0  0  0  0  0  0
    M  END
    $MOL

      AsciiChem

      1  0  0  0  0  0  0  0  0  0999 V2000
       12.0000   12.0000    0.0000 O   0  0  0  0  0  0  0  0  0  0  0  0  0
    M  END
  RXN
  water_rauxinfo_group = '0/N:1/rA:1nO/rB:/rC:12,12,0;'

  describe 'against a built cdylib' do
    let(:engine) { described_class.new(lib: lib) }

    it 'derives the five oracle lines from an RXNfile (headers included)' do
      record = engine.derive_from_rxnfile(water_rxn)
      expect(record).to be_a(AsciiChem::Rinchi::Record)
      expect(record.rinchi).to eq('RInChI=1.00.1S/H2O/h1H2<>H2O/h1H2/d+')
      expect(record.rauxinfo)
        .to eq("RAuxInfo=1.00.1/#{water_rauxinfo_group}<>#{water_rauxinfo_group}")
      expect(record.rinchikey)
        .to eq('Short-RInChIKey=SA-FUHFF-XLYOFNOQVP-XLYOFNOQVP-UHFFFADPSC-NUHFF-NUHFF-NUHFF-ZZZ')
      expect(record.long_key)
        .to eq('Long-RInChIKey=SA-FUHFF-XLYOFNOQVPJJNP-UHFFFAOYSA-N--XLYOFNOQVPJJNP-UHFFFAOYSA-N')
      expect(record.web_key).to eq('Web-RInChIKey=XLYOFNOQVPJJNPIXP-NUHFFFADPSCTJSA')
    end

    it 'derives the identifier line only from an RDfile' do
      # The RD edge exports the identifier only on this transport; the
      # other fields stay nil (the record carries what it provides).
      # The shape is the reader's minimum: the $RDFILE/$DATM/$RFMT
      # header, the $RXN block verbatim, and a non-agent $DATUM line
      # ending the walk.
      water_mol = <<~MOL
        $MOL

          AsciiChem

          1  0  0  0  0  0  0  0  0  0999 V2000
           12.0000   12.0000    0.0000 O   0  0  0  0  0  0  0  0  0  0  0  0  0
        M  END
      MOL
      rdfile = <<~RD
        $RDFILE 1
        $DATM 2026-11-03 12:00:00
        $RFMT $RIREG 42
        $RXN
        water-is-water
          chemomer

          1  1
        #{water_mol}#{water_mol}$DTYPE RXN:RXNREGNO
        $DATUM 42
      RD
      record = engine.derive_from_rdfile(rdfile)
      expect(record.rinchi).to eq('RInChI=1.00.1S/H2O/h1H2<>H2O/h1H2/d+')
      expect(record.rauxinfo).to be_nil
      expect(record.rinchikey).to be_nil
    end

    it 'decodes a RInChI with its companion into the resolved roles' do
      decoded = engine.decode('RInChI=1.00.1S/H2O/h1H2<>H2O/h1H2/d+',
                              rauxinfo: "RAuxInfo=1.00.1/#{water_rauxinfo_group}<>#{water_rauxinfo_group}")
      expect(decoded.directionality).to eq(:directional)
      expect(decoded.reactants.map(&:inchi)).to eq(['InChI=1S/H2O/h1H2'])
      expect(decoded.products.map(&:inchi)).to eq(['InChI=1S/H2O/h1H2'])
      expect(decoded.agents).to eq([])
      expect(decoded.reactants.first.aux)
        .to eq("AuxInfo=1/#{water_rauxinfo_group}")
      expect(decoded.reactants.first.inchikey).to eq('XLYOFNOQVPJJNP-UHFFFAOYSA-N')
    end

    it 'leaves the aux field empty on a bare decode' do
      decoded = engine.decode('RInChI=1.00.1S/H2O/h1H2<>H2O/h1H2/d+')
      expect(decoded.reactants.first.aux).to eq('')
    end

    it 'reads the direction flag and recovers the roles' do
      # A reversed recording (`/d-`: the products group sorts first):
      # the reader recovers the real roles from the flag.
      decoded = engine.decode('RInChI=1.00.1S/<>ClH/h1H!H3N/h1H3/d-')
      expect(decoded.directionality).to eq(:directional)
      expect(decoded.reactants.map(&:inchi))
        .to eq(['InChI=1S/ClH/h1H', 'InChI=1S/H3N/h1H3'])
      expect(decoded.products).to eq([])

      equilibrium = engine.decode('RInChI=1.00.1S/H2O/h1H2<>H2O/h1H2/d=')
      expect(equilibrium.directionality).to eq(:equilibrium)
    end

    it 'raises the engine error on a rejected RInChI, not a null crash' do
      # The error path must null?-check the returned POINTER (truthy
      # as an FFI object) and surface the engine's last_error.
      expect { engine.decode('RInChI=0.9/ nonsense') }
        .to raise_error(AsciiChem::Error, /chemomer native engine.*rxn:/)
    end

    it 'raises the engine error on a rejected RXNfile' do
      expect { engine.derive_from_rxnfile('not an rxnfile') }
        .to raise_error(AsciiChem::Error, /chemomer native engine.*\$RXN/)
    end
  end
end
