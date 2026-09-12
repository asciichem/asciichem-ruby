# frozen_string_literal: true

require_relative "../support/conformance_schemas"

# The vendored asciichem-model schemas stay internally coherent:
# positive examples validate against their node schema, negative
# examples (99-*) are rejected.
RSpec.describe "vendored model schemas" do
  it "has the full v1 schema set" do
    expect(ConformanceSchemas.positive_examples.length).to be >= 9
  end

  it "validates every positive example" do
    ConformanceSchemas.positive_examples.each do |path|
      data = YAML.safe_load_file(path, aliases: true)
      expect(ConformanceSchemas.validate(data)).to be_empty, path
    end
  end

  it "rejects every negative example" do
    ConformanceSchemas.negative_examples.each do |path|
      data = YAML.safe_load_file(path, aliases: true)
      expect(ConformanceSchemas.validate(data)).not_to be_empty, path
    end
  end
end
