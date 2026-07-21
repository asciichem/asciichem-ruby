# frozen_string_literal: true

require 'nokogiri'

module AsciiChem
  module Cml
    # Carries per-reaction conditions (above/below the arrow) through
    # CML round-trip. v0.11.0+: chemicalml 0.3.0 Reaction wire now
    # serialises `<conditionList>` natively, so conditions are emitted
    # by the adapter directly. This module now handles ONLY:
    #
    # - Parse legacy `<conditionList>` from XML (for files written by
    #   other CML tools or older AsciiChem versions using aci: attrs)
    # - Parse legacy `aci:conditionsAbove`/`aci:conditionsBelow`
    #   attributes for backwards compat
    #
    # The inject path is retained only to support test fixtures that
    # build XML by hand; production emit goes through the adapter.
    module ConditionsExtensions
      # Inject aci:conditionsAbove/Below attributes for legacy consumers.
      # v0.11.0+: native <conditionList> is emitted by the adapter, so
      # this is now suppressed unless conditions are missing from the
      # XML (defensive — shouldn't normally trigger).
      def self.inject(xml, formula)
        conditions_map = build_conditions_map(formula)
        return xml if conditions_map.empty?

        # If native <conditionList> already present, skip aci: emit.
        doc_check = Nokogiri::XML(xml)
        return xml if doc_check.xpath('//cml:reaction/cml:conditionList',
                                      cml: Extensions::CML_NS).any?

        doc = Nokogiri::XML(xml)
        root = doc.root
        Extensions.ensure_namespace(root)
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
      end
    end
  end
end
