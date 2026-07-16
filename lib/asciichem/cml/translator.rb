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
          inject_molecule_extensions(xml, formula, translation)
        end

        def to_asciichem(xml)
          ensure_schema_registered!
          top_level = Extensions.extract_top_level(xml)
          atom_extensions = Extensions.extract(xml)
          group_extensions = GroupExtensions.extract(xml)
          wire_doc = Chemicalml::Cml::Document.from_xml(xml)
          formula = AsciiChem::ModelAdapter.from_canonical(wire_doc)
          Extensions.restore(formula, wire_doc, atom_extensions)
          GroupExtensions.restore(formula, wire_doc, group_extensions)
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
