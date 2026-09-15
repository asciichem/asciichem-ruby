# frozen_string_literal: true

# Opt-in soft dependency: fail with guidance, never silently.
begin
  require 'parsanol/parslet'
  # parsanol-ruby 1.3.16's native.rb references
  # Parsanol::Native::Dynamic from the serializer without loading it
  # (parsanol-ruby#25).
  require 'parsanol/native/dynamic'
rescue LoadError => e
  raise AsciiChem::Engine::NotAvailableError,
        'the parsanol engine requires the parsanol gem — add gem "parsanol", "~> 1.3.16" ' \
        "to your Gemfile (#{e.message})"
end

module AsciiChem
  module Engine
    # The Parsanol engine: the SAME rules (GrammarRules /
    # TransformRules) over Parsanol's Rust-backed parslet-compat
    # layer. Corpus-identical to :parslet (221/221 byte-for-byte,
    # benchmarks/parsanol_recheck.rb) at ~3x parse speed.
    class ParsanolEngine
      # Backend twins of the reference classes; the shared rules
      # modules are the single source of grammar truth.
      class Grammar < ::Parsanol::Parslet::Parser
        include AsciiChem::GrammarRules
      end

      # Transform twin; #apply normalizes the engine's merged sibling
      # captures before the shared rules run (see split_merged_formula).
      class Transform < ::Parsanol::Parslet::Transform
        include AsciiChem::TransformRules

        # Engine divergence seam: parslet yields repeated sibling
        # node captures as an array of single-key hashes; parsanol
        # merges them into one hash, which no rule can match. Split
        # the merged form back before the shared rules run, so the
        # rules stay engine-agnostic (single source of truth).
        def apply(tree, context = nil)
          super(ParsanolEngine.split_merged_formula(tree), context)
        end
      end

      class << self
        # NODE_STARTERS mirrors the grammar's `node` alternatives
        # (grammar_rules.rb): the capture key each alternative
        # produces FIRST. A new node group begins at each starter;
        # continuation keys (arrow/products, coefficient/annotations,
        # crystal_name/params/body, ...) attach to the current group.
        NODE_STARTERS = %i[
          cascade reactants electron_config crystal_node spectrum_node
          calc_node zmatrix_node mechanism_node mol units math_source text_run
        ].freeze

        # Grammar truth: a molecule node is {coefficient? stereo? units}
        # — coefficient/stereo may LEGITIMATELY precede :units in one
        # node. They are prefixes, not new-node markers.
        PREFIX_KEYS = %i[coefficient stereo].freeze

        def split_merged_formula(node)
          case node
          when Hash
            node.to_h { |key, value| [key, split_formula_value(key, value)] }
          when Array
            node.map { |member| split_merged_formula(member) }
          else
            node
          end
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

        def split_formula_value(key, value)
          if key == :formula && value.is_a?(Hash) && value.length > 1
            groups = []
            value.each do |k, v|
              groups << {} if new_group?(groups, k)
              groups.last[k] = split_merged_formula(v)
            end
            groups.length == 1 ? groups.first : groups
          else
            split_merged_formula(value)
          end
        end

        def new_group?(groups, key)
          return true if groups.empty?

          return false unless NODE_STARTERS.include?(key)

          # :units continues a group that so far holds only molecule
          # prefixes ({coefficient:...} / {stereo:...}).
          !(key == :units && groups.last.keys.all? { |pk| PREFIX_KEYS.include?(pk) })
        end
      end
    end
  end
end
