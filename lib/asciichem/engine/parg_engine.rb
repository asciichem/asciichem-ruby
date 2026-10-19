# frozen_string_literal: true

# Opt-in soft dependency: fail with guidance, never silently.
begin
  require 'parsanol/parslet'
  require 'parsanol/parg'
  require 'parsanol/native/dynamic'
rescue LoadError => e
  raise AsciiChem::Engine::NotAvailableError,
        'the parg engine requires the parsanol gem (>= 1.3.94 for PARG) — ' \
        'add gem "parsanol" to your Gemfile ' \
        "(#{e.message})"
end

module AsciiChem
  module Engine
    # The PARG engine: parses through the compiled AsciiChem PARG
    # artifact (grammar/asciichem.parg in asciichem-parg, vendored at
    # lib/asciichem/engine/parg/asciichem.json) and adapts its parse
    # tree to the DSL shapes TransformRules consumes. The shared
    # conformance corpus passes model-identically (227/227) against
    # the reference engine (benchmarks/parg_recheck.rb).
    #
    # Tree shape: repetition flattening follows parslet's own
    # hash-only semantics (parsanol-ruby#231/#232), so the grammar
    # captures every structural rule — keeping every iteration a
    # hash — and TreeAdapter unwraps the wrappers into the DSL
    # shapes. Grammar#parse additionally fails when the tree covers
    # less input than was matched (a grammar edit leaving a trailing
    # literal uncaptured), a capture-completeness invariant rather
    # than end-of-input handling: the runtime itself is parslet-strict.
    class PargEngine
      # Version the vendored artifact was built from; the load fails
      # loudly on drift so the engine never runs a stale grammar.
      PARG_GRAMMAR_VERSION = '0.3.1'

      ARTIFACT_PATH = File.expand_path('parg/asciichem.json', __dir__)

      class Transform < ::Parsanol::Parslet::Transform
        include AsciiChem::TransformRules
      end

      # Grammar seam for Parser: #parse returns the adapted tree the
      # shared TransformRules consume, raising Parsanol::ParseFailed
      # (with a char position) on rejection or short matches.
      class Grammar
        def parse(text)
          source = text.strip
          raw = PargEngine.artifact.parse('formula', source)
          unless TreeAdapter.consumed_length(raw) >= source.length
            raise ::Parsanol::ParseFailed,
                  "Failed to match sequence at char #{TreeAdapter.consumed_length(raw)}: " \
                  'input not fully captured'
          end

          TreeAdapter.adapt(raw)
        end
      end

      # Unwraps the artifact tree's captured structural rules into the
      # DSL shapes TransformRules matches on.
      module TreeAdapter
        WRAPPERS = %i[
          molecule reaction annotated_molecule segment plus_term
          annotation_item formula_tail condition embedded_math
        ].freeze

        # Sequence captures whose merged array form collapses to the
        # single hash the DSL shape carries.
        ARRAY_MERGE_KEYS = %i[cascade molecule annotated_molecule].freeze

        private_constant :WRAPPERS, :ARRAY_MERGE_KEYS

        module_function

        def consumed_length(node)
          case node
          when ::Parsanol::Slice then node.offset + node.content.length
          when Hash then node.values.sum { |value| consumed_length(value) }
          when Array then node.map { |member| consumed_length(member) }.max.to_i
          else 0
          end
        end

        def adapt(node)
          case node
          when ::Parsanol::Slice then node.to_s
          when Hash then normalise(node.to_h { |key, value| [key.to_sym, adapt(value)] })
          when Array then node.map { |member| adapt(member) }
          else node
          end
        end

        def normalise(hash)
          return unwrap_single_key(hash) if hash.length == 1

          ARRAY_MERGE_KEYS.each do |key|
            hash[key] = merge_items(hash[key]) if array_value?(hash, key)
          end
          hash
        end

        def unwrap_single_key(hash)
          key = hash.keys.first
          return { math_source: math_source_of(hash[key]) } if key == :embedded_math

          return hash[key] if WRAPPERS.include?(key)
          return merge_multiplicity(merge_items(hash[key])) if key == :group

          hash
        end

        def math_source_of(inner)
          inner.is_a?(Hash) ? inner[:math_source] : inner
        end

        def array_value?(hash, key)
          hash.key?(key) && hash[key].is_a?(Array)
        end

        def merge_multiplicity(merged)
          merged[:multiplicity] ||= nil
          merged
        end

        # Captured sequences with embedded repetitions yield arrays
        # of per-child capture hashes; merge them into the single hash
        # the DSL shape carries (later duplicate keys append, matching
        # parslet's repeated-capture behavior).
        def merge_items(items)
          return items unless items.is_a?(Array)

          items.each_with_object({}) do |item, merged|
            merged.update(item) { |_key, old, new| old.is_a?(Array) ? old + Array(new) : new }
          end
        end
      end

      class << self
        def artifact
          @artifact ||= load_artifact
        end

        def grammar
          Grammar
        end

        def transform
          Transform
        end

        def parse_failed
          ::Parsanol::ParseFailed
        end

        def grammar_instance
          @grammar_instance ||= grammar.new
        end

        def transform_instance
          @transform_instance ||= transform.new
        end

        private

        def load_artifact
          artifact = ::Parsanol::PARG::Artifact.load(ARTIFACT_PATH)
          version = artifact.version
          return artifact if version == PARG_GRAMMAR_VERSION

          raise NotAvailableError,
                "vendored PARG artifact version #{version.inspect} does not match " \
                "the engine's pinned grammar #{PARG_GRAMMAR_VERSION.inspect} — " \
                're-vendor from asciichem-parg'
        end
      end
    end
  end
end
