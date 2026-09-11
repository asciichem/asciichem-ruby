# frozen_string_literal: true

require "spec_helper"
require_relative "../support/conformance_report"

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

  parser_cases.each do |fixture|
    id = fixture.fetch("id")
    input = fixture.fetch("input")

    if fixture.fetch("parses")
      it "#{id} parses cleanly" do
        expect { AsciiChem.parse(input) }.not_to raise_error
      end

      it "#{id} emits schema-valid canonical JSON (L0)" do
        require "asciichem_model"
        json = AsciiChem.parse(input).to_model_json
        errors = AsciiChemModel::Validators.validate(JSON.parse(json))
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
