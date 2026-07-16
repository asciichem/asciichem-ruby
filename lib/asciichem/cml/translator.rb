# frozen_string_literal: true

require "chemicalml"

module AsciiChem
  module Cml
    # Thin adapter between AsciiChem::Model and Chemicalml::Cml wire
    # classes. chemicalml 0.2.1+ merged the canonical Model into the
    # wire classes — Schema3::Atom, Schema3::Molecule, etc. handle both
    # serialization and semantics. This class:
    #
    # 1. Builds a Chemicalml::Cml::Document from AsciiChem::Model::Formula
    # 2. Serializes to XML (optionally enriching with aci: extensions)
    # 3. Parses CML XML back into AsciiChem::Model::Formula
    #
    # The aci: extension namespace (oxidation state, Lewis markers, ring
    # closures, groups, electron config, math, text, metadata) is handled
    # by post-processing the XML via Extensions and GroupExtensions.
    class Translator
      class << self
        def from_asciichem(formula)
          ensure_schema_registered!
          translation = AsciiChem::ModelAdapter.to_canonical_with_mapping(formula)
          xml = translation.document.to_xml
          xml = inject_atom_extensions(xml, translation.atom_mapping)
          xml = inject_reaction_conditions(xml, formula)
          xml = inject_metadata(xml, formula)
          inject_molecule_extensions(xml, formula, translation)
        end

        def to_asciichem(xml)
          ensure_schema_registered!
          top_level = Extensions.extract_top_level(xml)
          atom_extensions = Extensions.extract(xml)
          group_extensions = GroupExtensions.extract(xml)
          metadata_map = extract_metadata(xml)
          reaction_conditions = extract_reaction_conditions(xml)
          wire_doc = Chemicalml::Cml::Document.from_xml(xml)
          formula = AsciiChem::ModelAdapter.from_canonical(wire_doc)
          Extensions.restore(formula, wire_doc, atom_extensions)
          GroupExtensions.restore(formula, wire_doc, group_extensions)
          restore_reaction_conditions(formula, reaction_conditions)
          restore_metadata(formula, metadata_map)
          Extensions.restore_top_level(formula, top_level)
          formula
        end

        private

        def build_wire_document(document)
          molecules = document.molecules.map { |m| m }
          reactions = document.reactions.map { |r| r }
          reaction_lists = document.reaction_lists.map { |l| l }
          Chemicalml::Cml::Document.new(
            molecules: molecules,
            reactions: reactions,
            reaction_lists: reaction_lists
          )
        end

        def inject_atom_extensions(xml, atom_mapping)
          extensions = Extensions.collect(atom_mapping)
          Extensions.inject(xml, extensions)
        end

        # Inject reaction conditions via aci: attributes. Each Reaction
        # in the formula with conditions produces aci:conditionsAbove
        # and aci:conditionsBelow attributes on its <reaction> element.
        def inject_reaction_conditions(xml, formula)
          require 'nokogiri'
          doc = Nokogiri::XML(xml)
          root = doc.root
          reactions = formula.nodes.select { |n| n.is_a?(AsciiChem::Model::Reaction) }
          return xml if reactions.empty?

          root.add_namespace(Extensions::PREFIX, Extensions::NAMESPACE) unless root.namespaces.value?(Extensions::NAMESPACE)
          reactions.each_with_index do |reaction, idx|
            next unless reaction.conditions

            reaction_el = root.at_xpath("//cml:reaction[@id='r#{idx + 1}']", cml: Extensions::CML_NS)
            next unless reaction_el

            reaction_el["#{Extensions::PREFIX}:conditionsAbove"] = reaction.conditions.above if reaction.conditions.above
            reaction_el["#{Extensions::PREFIX}:conditionsBelow"] = reaction.conditions.below if reaction.conditions.below
          end
          doc.to_xml
        end

        def extract_reaction_conditions(xml)
          require 'nokogiri'
          doc = Nokogiri::XML(xml)
          result = {}
          doc.xpath("//cml:reaction", cml: Extensions::CML_NS).each do |el|
            id = el['id']
            next unless id

            above = el["#{Extensions::PREFIX}:conditionsAbove"]
            below = el["#{Extensions::PREFIX}:conditionsBelow"]
            result[id] = { above: above, below: below } if above || below
          end
          result
        end

        def restore_reaction_conditions(formula, conditions)
          return formula if conditions.empty?

          formula.nodes.each_with_index do |node, idx|
            next unless node.is_a?(AsciiChem::Model::Reaction)

            data = conditions["r#{idx + 1}"]
            next unless data

            node.conditions = AsciiChem::Model::Reaction::Conditions.new(
              above: data[:above],
              below: data[:below]
            )
          end
          formula
        end

        # Inject molecule metadata via aci: attributes on <molecule>.
        # Each {name: "k", content: "v"} produces aci:meta-k="v".
        def inject_metadata(xml, formula)
          require 'nokogiri'
          doc = Nokogiri::XML(xml)
          root = doc.root
          molecules = formula.nodes.select { |n| n.is_a?(AsciiChem::Model::Molecule) }
          has_meta = molecules.any? { |m| !m.metadata.empty? }
          return xml unless has_meta

          root.add_namespace(Extensions::PREFIX, Extensions::NAMESPACE) unless root.namespaces.value?(Extensions::NAMESPACE)
          molecules.each_with_index do |mol, idx|
            next if mol.metadata.empty?

            mol_el = root.at_xpath("//cml:molecule[@id='m#{idx + 1}']", cml: Extensions::CML_NS)
            next unless mol_el

            mol.metadata.each do |m|
              mol_el["#{Extensions::PREFIX}:meta-#{m[:name]}"] = m[:content]
            end
          end
          doc.to_xml
        end

        def extract_metadata(xml)
          require 'nokogiri'
          doc = Nokogiri::XML(xml)
          result = {}
          doc.xpath("//cml:molecule", cml: Extensions::CML_NS).each do |el|
            id = el['id']
            next unless id

            meta = {}
            el.attributes.each do |name, attr|
              next unless name.start_with?('meta-')
              next unless attr.namespace && attr.namespace.prefix == Extensions::PREFIX

              key = name.sub('meta-', '')
              meta[key] = attr.value
            end
            result[id] = meta unless meta.empty?
          end
          result
        end

        def restore_metadata(formula, metadata_map)
          return formula if metadata_map.empty?

          formula.nodes.each_with_index do |node, idx|
            next unless node.is_a?(AsciiChem::Model::Molecule)

            meta = metadata_map["m#{idx + 1}"]
            next unless meta

            meta.each { |name, content| node.metadata << { name: name, content: content } }
          end
          formula
        end

        def inject_molecule_extensions(xml, formula, translation)
          xml = inject_groups(xml, formula, translation)
          inject_top_level(xml, formula)
        end

        def inject_groups(xml, formula, translation)
          groups = translation.respond_to?(:groups) ? translation.groups : {}
          GroupExtensions.inject(xml, GroupExtensions.collect(groups))
        end

        def inject_top_level(xml, formula)
          top_level = Extensions.collect_top_level(formula)
          Extensions.inject_top_level(xml, top_level)
        end

        def ensure_schema_registered!
          Chemicalml::Cml::Schema3.ensure_registered!
        end
      end
    end
  end
end
