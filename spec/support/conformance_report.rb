# frozen_string_literal: true

# Writes conformance.json (per the asciichem-tests schema) after the
# suite finishes, so CI can publish the report and the spec site can
# render the implementation-status table.
RSpec.configure do |config|
  config.after(:suite) do
    examples = RSpec.world.example_groups.flat_map(&:descendants)
                        .flat_map(&:examples)
    corpus_examples = examples.select do |e|
      e.metadata[:example_group][:description] == "asciichem-tests conformance corpus"
    end
    next if corpus_examples.empty?

    def level(examples, marker)
      status = ->(e) { e.execution_result.respond_to?(:status) ? e.execution_result.status : nil }
      relevant = examples.select { |e| e.description.include?(marker) && status.call(e) != :pending }
      { "pass" => relevant.count { |e| status.call(e) == :passed }, "total" => relevant.length }
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
        "L4" => level(corpus_examples, "linter diagnostics")
      }
    }
    File.write("conformance.json", "#{JSON.pretty_generate(report)}\n")
  end
end
