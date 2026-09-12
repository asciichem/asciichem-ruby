# frozen_string_literal: true

require "json_schemer"
require "yaml"

# Schema validation over the vendored asciichem-model v1 wire
# schemas (spec/schemas, refreshed by scripts/update-model-schemas.sh).
# Each implementation validates its own emission this way — the same
# pattern asciichem-ts uses (ajv over the schemas). The contract repo
# is implementation-independent and is not distributed as a rubygem.
module ConformanceSchemas
  SCHEMA_DIR = File.expand_path("../schemas", __dir__)
  NEGATIVE_MARKER = "99-"
  private_constant :NEGATIVE_MARKER

  class << self
    # Validates a wire-form node hash against its node schema
    # (chosen by the `type` discriminator). Returns an Array of error
    # strings (empty when valid).
    def validate(node)
      schema_name = node.fetch("type").tr("_", "-")
      schemer = schemers.fetch(schema_name) do
        raise KeyError, "no schema for node type #{schema_name.inspect}"
      end
      schemer.validate(node).map(&:to_s)
    end

    def positive_examples
      example_files.reject { |p| File.basename(p).start_with?(NEGATIVE_MARKER) }
    end

    def negative_examples
      example_files.select { |p| File.basename(p).start_with?(NEGATIVE_MARKER) }
    end

    private

    # Sibling schemas are loaded exactly once and the SAME object is
    # returned for every $ref resolution — json_schemer retains one
    # compiled subschema per resolved object.
    def schemers
      @schemers ||= schema_files.to_h do |path|
        [File.basename(path, ".yaml"), schemer_for(path)]
      end
    end

    def schema_files
      Dir[File.join(SCHEMA_DIR, "*.yaml")].sort
    end

    def schemer_for(path)
      JSONSchemer.schema(YAML.safe_load_file(path), ref_resolver: method(:resolve_ref))
    end

    def resolve_ref(uri)
      basename = File.basename(uri.to_s)
      return loaded_schema(basename) if File.exist?(schema_file(basename))

      raise KeyError, "unresolvable $ref #{uri} (only sibling schema files are supported)"
    end

    def loaded_schema(basename)
      @loaded_schemas ||= {}
      @loaded_schemas[basename] ||= YAML.safe_load_file(schema_file(basename))
    end

    def schema_file(name)
      base = name.end_with?(".yaml") ? name : "#{name}.yaml"
      File.join(SCHEMA_DIR, base)
    end

    def example_files
      Dir[File.join(SCHEMA_DIR, "examples", "*.yaml")].sort
    end
  end
end
