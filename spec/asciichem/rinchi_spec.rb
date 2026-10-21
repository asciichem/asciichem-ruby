# frozen_string_literal: true

require 'spec_helper'

# Reaction identity via RInChI (TODO.v2/13 item 4): opt-in engine,
# model → RXN → rinchi-1 → RInChI keys.
RSpec.describe AsciiChem::Rinchi do
  let(:stub_bin) { File.expand_path('../fixtures/rinchi/stub-rinchi-cmdline', __dir__) }
  let(:reaction) { AsciiChem.parse('C-C-O -> C-C=O').nodes.first }

  after { AsciiChem::Rinchi.engine = nil }

  describe '.identity_for' do
    it 'raises EngineMissingError with install guidance when no engine is configured' do
      expect { described_class.identity_for(reaction) }
        .to raise_error(AsciiChem::EngineMissingError, /install the IUPAC RInChI software/)
    end

    it 'derives reaction identity through the configured engine' do
      described_class.engine = AsciiChem::Rinchi::BinaryEngine.new(bin: stub_bin)
      identity = described_class.identity_for(reaction)
      expect(identity.rinchi).to start_with('RInChI=1.')
      expect(identity.short_rinchikey).to be_a(String)
      expect(identity.long_rinchikey).to be_a(String)
    end

    it 'prefers an engine passed per call over the configured one' do
      described_class.engine = AsciiChem::Rinchi::BinaryEngine.new(bin: 'not-a-binary-xyz')
      identity = described_class.identity_for(
        reaction, engine: AsciiChem::Rinchi::BinaryEngine.new(bin: stub_bin)
      )
      expect(identity.rinchi).to start_with('RInChI=1.')
    end
  end

  describe AsciiChem::Rinchi::BinaryEngine do
    let(:engine) { described_class.new(bin: stub_bin) }

    it 'pipes the reaction through an RXN file into the engine' do
      # The stub only answers for 1 reactant / 1 product; a 2/2
      # reaction must fail loudly through the engine's exit status.
      expect { engine.identity(AsciiChem.parse('A + B -> C + D').nodes.first) }
        .to raise_error(AsciiChem::Error, /does not know this reaction/)
    end

    it 'raises EngineMissingError for a missing binary' do
      expect { described_class.new(bin: 'not-a-binary-xyz').identity(reaction) }
        .to raise_error(AsciiChem::EngineMissingError, /not found/)
    end
  end

  # End-to-end against the REAL IUPAC binary when one is present
  # (build: clone IUPAC-InChI/InChI at v1.07.5 and IUPAC-InChI/RInChI
  # side by side, make -f Makefile-Mac in
  # RInChI/src/example_apps/rinchi_cmdline after switching -ansi to
  # -std=gnu99 and regenerating the makefile's stale InChI source list).
  describe 'real binary', gated_real: true do
    it 'derives direction-distinct identities both ways' do
      bin = ENV.fetch('ASCIICHEM_RINCHI_BIN', nil)
      skip 'set ASCIICHEM_RINCHI_BIN to run the check' unless bin

      engine = AsciiChem::Rinchi::BinaryEngine.new(bin: bin)
      forward = AsciiChem.parse('C-C-O -> C-C=O').nodes.first
      reverse = AsciiChem.parse('C-C=O -> C-C-O').nodes.first

      forward_id = AsciiChem::Rinchi.identity_for(forward, engine: engine)
      reverse_id = AsciiChem::Rinchi.identity_for(reverse, engine: engine)

      expect(forward_id.rinchi).to start_with('RInChI=1.')
      expect(forward_id.long_rinchikey).to be_a(String)
      expect(forward_id.rinchi).not_to eq(reverse_id.rinchi)
    end
  end
end
