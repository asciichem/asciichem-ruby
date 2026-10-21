# frozen_string_literal: true

require "spec_helper"
require_relative "../support/conformance_report"
require_relative "../support/conformance_schemas"

# Conformance runner for the shared corpus (asciichem-tests).
# Executes every fixture against this implementation:
#
#   L0 — parse → canonical JSON → schema-validate (asciichem-model)
#   L1 — Text round-trip (roundTrip)
#   L3 — CML three-way round-trip (cmlRoundTrip)
#   L4 — linter diagnostics (lint)
#
# plus the error contract: rejects must raise ParseError and nothing
# else. A sibling checkout of asciichem-tests is required; CI clones
# it. conformance.json is written at suite end
# (spec/support/conformance_report.rb).
RSpec.describe "asciichem-tests conformance corpus" do
  corpus_files = begin
    gem_root = File.expand_path("../..", __dir__)
    corpus_dir = ENV.fetch("ASCIICHEM_CORPUS", nil) || File.join(gem_root, "..", "asciichem-tests", "corpus", "fixtures")
    raise "corpus not found at #{corpus_dir} (clone asciichem-tests as a sibling or set ASCIICHEM_CORPUS)" unless File.directory?(corpus_dir)

    Dir[File.join(corpus_dir, "*.json")].sort
  end

  cases = corpus_files.flat_map { |path| JSON.parse(File.read(path)).map { |c| c.merge("_file" => File.basename(path)) } }

  it "loads a non-empty corpus" do
    expect(cases.length).to be > 100
  end

  parser_cases = cases.select { |c| c.key?("input") && !c.key?("lint") && !c.key?("convention") }

  # Structure interchange (TODO.v2 09): SMILES and molfile ingest under
  # their own keys; fixture strings hold the reference-canonical forms.
  smiles_cases = cases.select { |c| c.key?("smiles") }
  smiles_cases.each do |fixture|
    id = fixture.fetch("id")
    smiles = fixture.fetch("smiles")

    if fixture.fetch("parses")
      it "#{id} ingests SMILES" do
        expect { AsciiChem.parse_smiles(smiles) }.not_to raise_error
      end

      it "#{id} round-trips via deterministic SMILES" do
        skip "not canonical form" unless fixture["smilesRoundTrip"]

        expect(AsciiChem.parse_smiles(smiles).to_smiles).to eq(smiles)
      end

      it "#{id} SMILES round-trips through AsciiChem text" do
        skip "not canonical form" unless fixture["smilesRoundTrip"]

        # Aromaticity and implicit hydrogens have no AsciiChem syntax
        # (they arrive via ingestion), so text round-trip is only
        # asserted where the text form is complete.
        mol = AsciiChem.parse_smiles(smiles)
        skip "not expressible in text" if mol.nodes.any? do |m|
          m.nodes.any? do |n|
            n.is_a?(AsciiChem::Model::Atom) &&
              (n.aromatic || n.hydrogens ||
               # Bare digits after H are subscripts, never ring
               # closures — a hydrogen cannot close a ring in text.
               (n.ring_closures && n.element == "H"))
          end
        end

        round = AsciiChem.parse(mol.to_text)
        expect(round.to_smiles).to eq(smiles)
      end
    else
      it "#{id} rejects SMILES with ParseError" do
        expect { AsciiChem.parse_smiles(smiles) }.to raise_error(AsciiChem::ParseError)
      end
    end
  end

  # Canonical SMILES (TODO.v2/13 item 2): the writer consumes the
  # perception pass, so Kekulé aromatic input canonicalizes to the
  # lowercase spelling. Fixtures whose input is not canonical state
  # the exact output.
  cases.select { |c| c.key?("canonicalSmiles") }.each do |fixture|
    id = fixture.fetch("id")

    it "#{id} canonicalizes to the perceived aromatic form" do
      expect(AsciiChem.parse_smiles(fixture.fetch("smiles")).to_smiles)
        .to eq(fixture.fetch("canonicalSmiles"))
    end
  end

  # Perception conformance (TODO.v2/13 item 2): implicit hydrogens and
  # aromatic rings are shared semantics — every implementation must
  # derive the same values (nil = perception declines, never invents).
  cases.select { |c| c.key?("perception") }.each do |fixture|
    id = fixture.fetch("id")
    expected = fixture.fetch("perception")

    it "#{id} perceives the shared implicit hydrogens" do
      molecule = AsciiChem.parse_smiles(fixture.fetch("smiles")).nodes.first
      atoms, edges = AsciiChem::Structure::Graph.build(molecule)
      actual = atoms.each_with_index.map do |atom, index|
        AsciiChem::Perception.implicit_hydrogens(
          atom, AsciiChem::Perception.hydrogen_valence_sum(index, edges)
        )
      end
      expect(actual).to eq(expected.fetch("implicitHydrogens"))
    end

    it "#{id} perceives the shared aromatic rings" do
      molecule = AsciiChem.parse_smiles(fixture.fetch("smiles")).nodes.first
      atoms, edges = AsciiChem::Structure::Graph.build(molecule)
      rings = AsciiChem::Perception.aromatic_rings(atoms, edges).map(&:sort).sort
      expect(rings).to eq(expected.fetch("aromaticRings"))
    end
  end

  # Structured condition entries (TODO.v2/13 item 4, slice 1): typed
  # `role: value` entries and free text are shared semantics — the
  # bracket text itself stays verbatim (round-trip source).
  cases.select { |c| c.key?("conditionEntries") }.each do |fixture|
    id = fixture.fetch("id")

    it "#{id} derives the shared condition entries" do
      reaction = AsciiChem.parse(fixture.fetch("input")).nodes.first
      actual = reaction.conditions.entries.map do |entry|
        { "role" => entry.role&.to_s, "value" => entry.value, "side" => entry.side.to_s }
      end
      expect(actual).to eq(fixture.fetch("conditionEntries"))
    end
  end

  # Mechanism electron-flow markers (TODO.v2/13 item 4): expected
  # flow markers per step label, carried by the steps.
  cases.select { |c| c.key?("flows") }.each do |fixture|
    id = fixture.fetch("id")

    it "#{id} carries the shared electron-flow markers" do
      mechanism = AsciiChem.parse(fixture.fetch("input")).nodes.first
      actual = mechanism.steps.to_h do |step|
        [step.label,
         (step.flows || []).map { |f| { "source" => f.source, "target" => f.target } }]
      end
      expect(actual).to eq(fixture.fetch("flows"))
    end
  end

  molfile_cases = cases.select { |c| c.key?("molfile") }
  molfile_cases.each do |fixture|
    id = fixture.fetch("id")
    molfile = fixture.fetch("molfile")

    if fixture.fetch("parses")
      it "#{id} ingests molfile with expected counts" do
        molecule = AsciiChem.parse_molfile(molfile)
        atoms, edges = AsciiChem::Structure::Graph.build(molecule)
        expect(atoms.length).to eq(fixture.fetch("atoms"))
        expect(edges.length).to eq(fixture.fetch("bonds"))
      end

      it "#{id} round-trips via molfile" do
        skip "not flagged" unless fixture["molfileRoundTrip"]

        molecule = AsciiChem.parse_molfile(molfile)
        atoms, edges = AsciiChem::Structure::Graph.build(molecule)
        shape = edges.map { |e| [e.from, e.to, e.kind] }.sort
        atoms2, edges2 = AsciiChem::Structure::Graph.build(
          AsciiChem.parse_molfile(AsciiChem::Molfile.write(molecule))
        )
        expect(atoms2.length).to eq(atoms.length)
        expect(edges2.map { |e| [e.from, e.to, e.kind] }.sort).to eq(shape)
      end
    else
      it "#{id} rejects molfile with ParseError" do
        expect { AsciiChem.parse_molfile(molfile) }.to raise_error(AsciiChem::ParseError)
      end
    end
  end

  parser_cases.each do |fixture|
    id = fixture.fetch("id")
    input = fixture.fetch("input")

    if fixture.fetch("parses")
      it "#{id} parses cleanly" do
        expect { AsciiChem.parse(input) }.not_to raise_error
      end

      it "#{id} emits schema-valid canonical JSON (L0)" do
        json = AsciiChem.parse(input).to_model_json
        errors = ConformanceSchemas.validate(JSON.parse(json))
        expect(errors).to be_empty, "#{id}: #{errors.join('; ')[0, 200]}"
      end

      it "#{id} round-trips via Text (L1)" do
        skip "not flagged" unless fixture["roundTrip"]

        expect(AsciiChem.parse(input).to_text).to eq(input)
      end

      it "#{id} round-trips via model JSON" do
        skip "not flagged" unless fixture["roundTrip"]

        restored = AsciiChem.from_model_json(AsciiChem.parse(input).to_model_json).to_text
        expect(restored).to eq(input), "restored #{restored.inspect}"
      end

      it "#{id} round-trips via CML (L3)" do
        skip "not flagged" unless fixture["cmlRoundTrip"]

        expect(AsciiChem::Cml.parse(AsciiChem.parse(input).to_cml).to_text).to eq(input)
      end
    else
      it "#{id} rejects with ParseError" do
        expect { AsciiChem.parse(input) }.to raise_error(AsciiChem::ParseError)
      end
    end
  end

  # L2: MathML golden parity — the reference implementation is the
  # source of the goldens; this block pins them against drift.
  cases.select { |c| c.key?("mathml") }.each do |fixture|
    id = fixture.fetch("id")

    it "#{id} matches the reference MathML golden (L2)" do
      expect(AsciiChem.parse(fixture.fetch("input")).to_mathml).to eq(fixture.fetch("mathml"))
    end
  end

  cases.select { |c| c.key?("lint") }.each do |fixture|
    id = fixture.fetch("id")
    input = fixture.fetch("input")
    expected = fixture.fetch("lint")

    it "#{id} produces the expected linter diagnostics (L4)" do
      diagnostics = AsciiChem::Linter.run(AsciiChem.parse(input))
      expected.each do |want|
        hit = diagnostics.any? do |d|
          d.severity == want.fetch("severity").to_sym && d.message.include?(want.fetch("messageIncludes"))
        end
        expect(hit).to be(true), "#{id}: no #{want['severity']} diagnostic matching #{want['messageIncludes'].inspect}"
      end
      expect(diagnostics.length).to eq(expected.length), "#{id}: expected exactly #{expected.length} diagnostics, got #{diagnostics.map(&:message).inspect[0, 200]}"
    end
  end
end
