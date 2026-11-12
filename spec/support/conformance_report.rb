# frozen_string_literal: true

# Writes conformance.json (per the asciichem-tests schema) after the
# suite finishes, so CI can publish the report and the spec site can
# render the implementation-status table.
RSpec.configure do |config|
  config.after(:suite) do
    examples = RSpec.world.example_groups.flat_map(&:descendants)
                        .flat_map(&:examples)
    # The corpus examples include the parity families, which live in
    # nested describe blocks — walk the parent-group chain.
    in_corpus = lambda do |e|
      group = e.metadata[:example_group]
      while group
        return true if group[:description] == "asciichem-tests conformance corpus"

        group = group[:parent_example_group]
      end
      false
    end
    corpus_examples = examples.select { |e| in_corpus.call(e) }
    next if corpus_examples.empty?

    def level(examples, marker)
      statuses = examples.map do |e|
        result = e.execution_result
        result.respond_to?(:status) ? result.status : nil
      end
      matching = examples.zip(statuses).select { |e, _| e.description.include?(marker) }.map(&:last)
      {
        # total = executed (passed or failed); skipped = the family's
        # skipped-and-reported cases (RSpec marks runtime skips
        # :pending) — posture-mismatched and pending ones.
        "pass" => matching.count(:passed),
        "total" => matching.count { |s| s != :pending },
        "skipped" => matching.count(:pending)
      }
    end

    report = {
      "implementation" => "asciichem-ruby",
      "version" => AsciiChem::VERSION,
      "corpusVersion" => ENV.fetch("ASCIICHEM_CORPUS_VERSION", "v0.2.0"),
      "timestamp" => Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
      "levels" => {
        "L0" => level(corpus_examples, "schema-valid"),
        "L1" => level(corpus_examples, "via Text"),
        "L3" => level(corpus_examples, "via CML"),
        "L2" => level(corpus_examples, "MathML golden"),
        "L4" => level(corpus_examples, "linter diagnostics"),
        "resolver" => level(corpus_examples, "replays the recorded resolver exchange"),
        "citation" => level(corpus_examples, "bibitem bytes"),
        "cli" => level(corpus_examples, "CLI contract invocation")
      }
    }
    File.write("conformance.json", "#{JSON.pretty_generate(report)}\n")
  end
end
