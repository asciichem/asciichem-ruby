# frozen_string_literal: true

require "spec_helper"
require "digest"
require "json"
require "stringio"
require "tmpdir"
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
  smiles_cases = cases.select { |c| c.key?("smiles") && c.key?("parses") }
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

  molfile_cases = cases.select { |c| c.key?("molfile") && c.key?("parses") }
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

  # L4: linter diagnostics — engine-scaled (suite 0.11.0). The identity
  # cross-check derives the drawn structure's InChI in-process once the
  # engine seam is configured, so this runner's posture is "inchi" and
  # it configures the offline stub engine for the family's duration;
  # the engine:"inchi" cases run everywhere CI runs. Cases marked
  # engine:"none" encode the no-engine posture: they skip and report —
  # a missing engine is a posture, not a failure.
  lint_cases = cases.select { |c| c.key?("lint") }
  describe "L4 linter diagnostics" do
    corpus_stub = File.expand_path("../fixtures/inchi/stub-inchi-1-corpus", __dir__)
    posture = "inchi"

    around do |example|
      previous = AsciiChem::Inchi.engine
      AsciiChem::Inchi.engine = AsciiChem::Inchi::BinaryEngine.new(bin: corpus_stub)
      example.run
    ensure
      AsciiChem::Inchi.engine = previous
    end

    # The contract's match semantics: every expectation matches at
    # least one actual diagnostic (severity, message containing
    # messageIncludes and — when given — the same node label) AND
    # every actual diagnostic matches at least one expectation.
    # lint: [] demands a completely clean run.
    matcher = lambda do |want, diagnostic|
      diagnostic.severity == want.fetch("severity").to_sym &&
        diagnostic.message.include?(want.fetch("messageIncludes")) &&
        (want["node"].nil? || diagnostic.node&.diagnostic_label == want["node"])
    end

    lint_cases.each do |fixture|
      id = fixture.fetch("id")
      marked = fixture["engine"]

      it "#{id} produces the expected linter diagnostics (L4)" do
        if marked && marked != posture
          skip "engine posture #{marked.inspect} != this run's #{posture.inspect}; " \
               "the case is exercised by the matching-posture run"
        end
        pending_list = fixture.fetch("pending", [])
        skip "pending for this implementation: #{pending_list.join(', ')}" if pending_list.include?("ruby")

        if fixture.fetch("parses")
          diagnostics = AsciiChem::Linter.run(AsciiChem.parse(fixture.fetch("input")))
          expected = fixture.fetch("lint")
          expected.each do |want|
            hit = diagnostics.any? { |d| matcher.call(want, d) }
            unless hit
              actual = diagnostics.map do |d|
                [d.severity, d.node&.diagnostic_label, d.message[0, 120]].compact.join(" | ")
              end
              raise "#{id}: no diagnostic matches #{want.inspect}; actual: #{actual.inspect}"
            end
          end
          diagnostics.each do |diagnostic|
            hit = expected.any? { |want| matcher.call(want, diagnostic) }
            unless hit
              label = diagnostic.node&.diagnostic_label
              excerpt = diagnostic.message[0, 120].inspect
              raise "#{id}: unexpected diagnostic (#{diagnostic.severity}, #{label}, #{excerpt})"
            end
          end
        else
          expect { AsciiChem.parse(fixture.fetch("input")) }.to raise_error(AsciiChem::ParseError)
        end
      end
    end

    it "reports the posture-skipped linter cases" do
      # The skip is part of the report, never silent: the corpus's
      # no-engine cases are listed here by id, and the list changes
      # only when the corpus's posture markers change.
      corpus_skipped = lint_cases
                       .select { |f| f["engine"] && f["engine"] != posture }
                       .map { |f| f["id"] }
      expect(corpus_skipped).to eq([
        "lint/inchi-molecule-mismatch",
        "lint/identity-skip-no-engine",
        "lint/inchi-unanalysable-no-engine"
      ])
    end
  end

  # Resolver family (suite 0.11.0): the recorded request/response is
  # replayed through the named source adapter — the adapter must build
  # exactly request.url for (source, convention, value) and send the
  # adapter-declared request.headers ("{api-key}" is the caller's key
  # placeholder). Feeding response.body must yield semantically the
  # expectation's substance wire record — every identifier and property
  # carrying its provenance with the pinned retrievedAt — plus
  # structureParses. The cache markers pin the shared caching contract
  # (ttlSeconds, keyFormula, servesOffline). A skipped outcome (the
  # key-absent 401) drops the source without poisoning the others.
  resolver_cases = cases.select { |c| c.key?("source") && c.key?("request") && c.key?("expectation") }
  describe "resolver replay" do
    # The retrieval time the corpus pins so replayed records and the
    # citation goldens that consume them are stable bytes.
    pinned_retrieved_at = lambda do |fixture|
      fixture.dig("expectation", "substance", "identifiers", 0, "provenance", "retrievedAt")
    end
    fake_key = "corpus-replay-test-key" # never a real credential

    # Key-hermetic: the corpus's key-absent case demands the no-key
    # posture, so the family runs with no key whatever the machine
    # carries in the env or the stored token file (the resolver
    # specs' direct const swap — no doubles involved).
    around do |example|
      key_file = AsciiChem::Resolver::CommonChemistry::KEY_FILE
      AsciiChem::Resolver::CommonChemistry.send(:remove_const, :KEY_FILE)
      AsciiChem::Resolver::CommonChemistry.const_set(:KEY_FILE, "/nonexistent")
      env_key = ENV.delete("COMMON_CHEMISTRY_API_KEY")
      example.run
    ensure
      AsciiChem::Resolver::CommonChemistry.send(:remove_const, :KEY_FILE)
      AsciiChem::Resolver::CommonChemistry.const_set(:KEY_FILE, key_file)
      ENV["COMMON_CHEMISTRY_API_KEY"] = env_key if env_key
    end

    # Answers with the recorded response; captures every request for
    # the URL/header assertions (a value fake carrying recorded data).
    replay_fetch_class = Struct.new(:fixture, :configured_key, :calls, keyword_init: true) do
      def get(url, headers = {})
        calls << [url, headers]
        status = fixture.dig("response", "status")
        body = fixture.dig("response", "body")
        return nil if status == 404
        raise AsciiChem::Error, "HTTP #{status}: replay" if status != 200

        body.is_a?(String) ? body : JSON.generate(body)
      end
    end

    # Network access from a cache-seeded lookup would be a bug.
    offline_fetch = Object.new
    def offline_fetch.get(url, _headers = {})
      raise AsciiChem::Error, "network must not be touched: #{url}"
    end

    # Routes by URL to the per-source recorded response (the fan-out's
    # one transport across the selected sources); captures requests.
    routing_fetch_class = Struct.new(:routes, :calls, keyword_init: true) do
      def source_of(url)
        routes.keys.find { |source| url.include?(source.tr("_", "")) }
      end

      def get(url, headers = {})
        calls << [url, headers]
        response = routes.fetch(source_of(url))
        status = response.fetch("status")
        body = response["body"]
        return nil if status == 404
        raise AsciiChem::Error, "HTTP #{status}: replay" if status != 200

        body.is_a?(String) ? body : JSON.generate(body)
      end
    end

    def adapter_for(fixture, keyed:, fake_key:)
      if fixture.fetch("source") == "common_chemistry"
        AsciiChem::Resolver::CommonChemistry.new(api_key: keyed ? fake_key : nil)
      else
        AsciiChem::Resolver[fixture.fetch("source")].new
      end
    end

    resolver_cases.each do |fixture|
      id = fixture.fetch("id")
      it "#{id} replays the recorded resolver exchange" do
        pending_list = fixture.fetch("pending", [])
        skip "pending for this implementation: #{pending_list.join(', ')}" if pending_list.include?("ruby")

        expectation = fixture.fetch("expectation")
        headers = fixture.dig("request", "headers") || {}
        keyed = headers.value?("{api-key}")
        cache = AsciiChem::Resolver::Cache.new(dir: File.join(Dir.tmpdir, "asciichem-corpus-resolver-#{rand(1e9)}"))
        replay = replay_fetch_class.new(fixture: fixture, configured_key: keyed ? fake_key : nil, calls: [])

        if expectation.fetch("outcome") == "skipped"
          # A source-level failure drops the source without poisoning
          # the others: the fan-out answers with the other sources
          # only, through one routed transport carrying each source's
          # recorded response (the skipped source's 401 posture stays
          # key-absent; the other source rides its recorded 200 body).
          answered = resolver_cases.find do |c|
            c.fetch("source") == "pubchem" && c.dig("expectation", "outcome") != "skipped"
          end
          routed = routing_fetch_class.new(
            routes: {
              fixture.fetch("source") => fixture.fetch("response"),
              "pubchem" => answered.fetch("response")
            },
            calls: []
          )
          results = AsciiChem::Resolver.resolve_all(
            value: fixture.fetch("value"), convention: fixture.fetch("convention"),
            sources: %w[common_chemistry pubchem], fetch: routed, cache: cache,
            now: pinned_retrieved_at.call(answered)
          )
          expect(results.map { |s| s.provenance.source }).to eq(%w[pubchem]),
                "#{id}: the skipped source must drop without poisoning the others"
          # The request assertions read the skipped source's captured
          # call (the routed transport carries it).
          expect(routed.calls.length).to eq(2), "#{id}: exactly one request per selected source"
          url, sent_headers = routed.calls.find { |(captured, _)| captured.include?("commonchemistry") }
          expect(url).not_to be_nil, "#{id}: the skipped source must still be tried"
        else
          substance = adapter_for(fixture, keyed: keyed, fake_key: fake_key).resolve(
            value: fixture.fetch("value"), convention: fixture.fetch("convention"),
            fetch: replay, cache: cache,
            now: pinned_retrieved_at.call(fixture)
          )
          expect(substance).not_to be_nil, "#{id}: the source must answer"
          # L0: the record validates against the asciichem-model v1
          # substance-record schema, then compares semantically (key
          # order cannot fail a case).
          wire = JSON.parse(substance.to_model_json)
          errors = ConformanceSchemas.validate(wire)
          expect(errors).to be_empty, "#{id}: #{errors.join('; ')[0, 200]}"
          expect(wire).to eq(expectation.fetch("substance")), "#{id}: substance record mismatch"
          structure_parses = expectation.fetch("structureParses")
          expect(substance.structure.nil?).to eq(!structure_parses), "#{id}: structureParses"
          expect(replay.calls.length).to eq(1), "#{id}: exactly one request"
          url, sent_headers = replay.calls.first
        end

        # The adapter must build exactly the recorded request.
        expect(url).to eq(fixture.dig("request", "url")), "#{id}: adapter URL"
        expected_headers = headers.merge(
          headers.select { |_, value| value == "{api-key}" }.to_h { |name, _| [name, fake_key] }
        )
        expect(sent_headers).to eq(expected_headers), "#{id}: request headers"

        # The cache markers pin the shared caching contract.
        cache_contract = expectation.fetch("cache", {})
        expect(AsciiChem::Resolver::Cache::DEFAULT_TTL).to eq(cache_contract.fetch("ttlSeconds")), "#{id}: ttlSeconds"
        expect(cache.key_for(fixture.fetch("source"), fixture.fetch("convention"), fixture.fetch("value")))
          .to eq(Digest::SHA256.hexdigest("#{fixture.fetch('source')}:#{fixture.fetch('convention')}:#{fixture.fetch('value')}")),
               "#{id}: #{cache_contract.fetch('keyFormula')}"

        next unless cache_contract.fetch("servesOffline")

        # A seeded entry answers without re-fetching — and without a
        # key, for key-gated sources.
        if expectation.fetch("outcome") == "skipped"
          seed_cache = AsciiChem::Resolver::Cache.new(
            dir: File.join(Dir.tmpdir, "asciichem-corpus-resolver-#{rand(1e9)}")
          )
          seed_body = resolver_cases
                      .find { |c| c.fetch("id") == "resolver/common-chemistry-cas-aspirin" }
                      .dig("response", "body")
          seed_fixture = { "id" => id, "source" => "common_chemistry",
                           "response" => { "status" => 200, "body" => seed_body } }
          AsciiChem::Resolver::CommonChemistry.new(api_key: fake_key).resolve(
            value: fixture.fetch("value"), convention: fixture.fetch("convention"),
            fetch: replay_fetch_class.new(fixture: seed_fixture, configured_key: fake_key, calls: []),
            cache: seed_cache, now: pinned_retrieved_at.call(fixture)
          )
          served = AsciiChem::Resolver.resolve_all(
            value: fixture.fetch("value"), convention: fixture.fetch("convention"),
            sources: [fixture.fetch("source")], fetch: offline_fetch, cache: seed_cache
          )
          expect(served.length).to eq(1), "#{id}: the seeded entry serves offline"
        else
          served = adapter_for(fixture, keyed: keyed, fake_key: fake_key).resolve(
            value: fixture.fetch("value"), convention: fixture.fetch("convention"),
            fetch: offline_fetch, cache: cache
          )
          served_wire = JSON.parse(served.to_model_json)
          expect(served_wire).to eq(expectation.fetch("substance")), "#{id}: the cached record serves offline"
        end
      end
    end
  end

  # Citation family (suite 0.11.0): for the fixture's substance record
  # (the wire form, retrieval time pinned) the citation layer must emit
  # exactly the bibitem bytes — byte-equal, no trailing newline. The
  # goldens were captured from this implementation.
  cases.select { |c| c.key?("substance") && c.key?("bibitem") }.each do |fixture|
    id = fixture.fetch("id")

    it "#{id} emits the corpus bibitem bytes" do
      substance = AsciiChem::Resolver::Substance.from_model_json(JSON.generate(fixture.fetch("substance")))
      if fixture["rejected"]
        expect { AsciiChem::Citation.bibitem(substance) }
          .to raise_error(AsciiChem::Error, /no provenance/)
      else
        expect(AsciiChem::Citation.to_xml(substance)).to eq(fixture.fetch("bibitem"))
      end
    end
  end

  # CLI family (suite 0.11.0): each case runs `invocation` (the argv
  # after the program name) against the CLI dispatch and asserts exit
  # plus the stdout/stderr matchers. stdout matchers are exact (with
  # "{version}" standing for this implementation's own version),
  # substring (every entry appears), or semantic JSON (parsed
  # comparison — key order cannot fail a case). Error text rides
  # stderr. Invoked in-process: no shell, real exit codes via the
  # raised SystemExit.
  cli_cases = cases.select { |c| c.key?("invocation") }
  describe "CLI contract" do
    def run_cli(argv)
      out = StringIO.new
      err = StringIO.new
      original_stdout, original_stderr = $stdout, $stderr
      $stdout, $stderr = out, err
      status = 0
      begin
        AsciiChem::Cli.start(Array(argv))
      rescue SystemExit => e
        status = e.status
      ensure
        $stdout, $stderr = original_stdout, original_stderr
      end
      [status, out.string, err.string]
    end

    cli_cases.each do |fixture|
      id = fixture.fetch("id")

      it "#{id} runs the CLI contract invocation" do
        pending_list = fixture.fetch("pending", [])
        skip "pending for this implementation: #{pending_list.join(', ')}" if pending_list.include?("ruby")

        status, stdout, stderr = run_cli(fixture.fetch("invocation"))
        detail = "exit #{status} (stdout: #{stdout.inspect[0, 120]}, stderr: #{stderr.inspect[0, 120]})"
        expect(status).to eq(fixture.fetch("exit")), "#{id}: #{detail}"

        if fixture.key?("stdout")
          expected = fixture.fetch("stdout").gsub("{version}", AsciiChem::VERSION)
          expect(stdout).to eq(expected), "#{id}: stdout #{stdout.inspect[0, 200]}"
        elsif fixture.key?("stdoutIncludes")
          fixture.fetch("stdoutIncludes").each do |fragment|
            expect(stdout).to include(fragment), "#{id}: stdout #{stdout.inspect[0, 200]}"
          end
        elsif fixture.key?("stdoutJson")
          expect(JSON.parse(stdout)).to eq(fixture.fetch("stdoutJson")), "#{id}: stdout JSON #{stdout.inspect[0, 200]}"
        end

        fixture.fetch("stderrIncludes", []).each do |fragment|
          expect(stderr).to include(fragment), "#{id}: stderr #{stderr.inspect[0, 200]}"
        end
      end
    end
  end
end
