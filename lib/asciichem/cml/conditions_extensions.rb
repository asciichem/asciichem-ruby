# frozen_string_literal: true

require 'nokogiri'

module AsciiChem
  module Cml
    # Carries per-reaction conditions (above/below the arrow) through
    # CML round-trip via `aci:conditionsAbove` / `aci:conditionsBelow`
    # attributes on `<reaction>` elements.
    #
    # CML's standard `<conditionList>` element exists but the
    # chemicalml Reaction wire doesn't serialize it (verified — see
    # TODO.beyond-formulas/17-chemicalml-wire-gaps.md). AsciiChem
    # carries conditions via the aci: namespace as a workaround.
    #
    # This is the sixth extension channel, parallel to:
    #   - Extensions (atom attributes + top-level constructs)
    #   - GroupExtensions (group structure inside molecules)
    #   - OpaqueExtensions (unknown top-level elements)
    #   - MetadataExtensions (per-molecule metadata)
    module ConditionsExtensions
      # Inject aci:conditionsAbove/Below attributes into the XML for
      # each reaction with conditions. No-op if no reaction has any.
      def self.inject(xml, formula)
        conditions_map = build_conditions_map(formula)
        return xml if conditions_map.empty?

        doc = Nokogiri::XML(xml)
        root = doc.root
        ensure_namespace(root)
        apply_conditions(root, conditions_map)
        doc.to_xml
      end

      # Extract aci:conditionsAbove/Below from each <reaction>.
      # Returns `{ reaction_id => { above:, below: } }`.
      def self.extract(xml)
        doc = Nokogiri::XML(xml)
        result = {}
        doc.xpath('//cml:reaction', cml: Extensions::CML_NS).each do |el|
          id = el['id']
          next unless id

          above = el["#{Extensions::PREFIX}:conditionsAbove"]
          below = el["#{Extensions::PREFIX}:conditionsBelow"]
          result[id] = { above: above, below: below } if above || below
        end
        result
      end

      # Restore extracted conditions onto matching reactions in a
      # freshly-parsed formula. Walks in canonical order to match IDs.
      def self.restore(formula, conditions_map)
        return formula if conditions_map.empty?

        prefix = AsciiChem::Cml::ID_PREFIXES.fetch(:reaction)
        index = 0
        each_reaction_in_canonical_order(formula) do |reaction|
          index += 1
          data = conditions_map["#{prefix}#{index}"]
          next unless data

          reaction.conditions = AsciiChem::Model::Reaction::Conditions.new(
            above: data[:above],
            below: data[:below]
          )
        end
        formula
      end

      class << self
        private

        def build_conditions_map(formula)
          prefix = AsciiChem::Cml::ID_PREFIXES.fetch(:reaction)
          index = 0
          map = {}
          each_reaction_in_canonical_order(formula) do |reaction|
            index += 1
            next unless reaction.conditions

            data = conditions_data(reaction)
            map["#{prefix}#{index}"] = data if data[:above] || data[:below]
          end
          map
        end

        def conditions_data(reaction)
          {
            above: reaction.conditions&.above,
            below: reaction.conditions&.below
          }
        end

        def each_reaction_in_canonical_order(formula, &block)
          formula.nodes.each do |node|
            case node
            when AsciiChem::Model::Reaction
              yield node
            when AsciiChem::Model::ReactionCascade
              node.steps.each(&block)
            end
          end
        end

        def apply_conditions(root, conditions_map)
          conditions_map.each do |reaction_id, data|
            reaction_el = root.at_xpath(
              "//cml:reaction[@id='#{reaction_id}']",
              cml: Extensions::CML_NS
            )
            next unless reaction_el

            apply_one_condition(reaction_el, data)
          end
        end

        def apply_one_condition(reaction_el, data)
          reaction_el["#{Extensions::PREFIX}:conditionsAbove"] = data[:above] if data[:above]
          return unless data[:below]

          reaction_el["#{Extensions::PREFIX}:conditionsBelow"] = data[:below]
        end

        def ensure_namespace(root)
          return if root.namespaces.value?(Extensions::NAMESPACE)

          root.add_namespace(Extensions::PREFIX, Extensions::NAMESPACE)
        end
      end
    end
  end
end
