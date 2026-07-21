# frozen_string_literal: true

require 'chemicalml'

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
          xml = ConditionsExtensions.inject(xml, formula)
          xml = MetadataExtensions.inject(xml, formula)
          xml = inject_molecule_extensions(xml, formula, translation)
          inject_opaque(xml, formula)
        end

        # Constructs that now have native CML wire representation
        # (chemicalml 0.3.0+). For each, suppress the aci: text carrier
        # on emit — the native wire carries the data. aci: fallback
        # still works on parse for backwards-compat with old files.
        NATIVELY_WIRED = [
          AsciiChem::Model::Crystal,
          AsciiChem::Model::Spectrum
        ].freeze

        def to_asciichem(xml)
          ensure_schema_registered!
          extracted = extract_all(xml)
          wire_doc = Chemicalml::Cml::Document.from_xml(extracted[:cleaned_xml])
          formula = AsciiChem::ModelAdapter.from_canonical(wire_doc)
          restore_all(formula, wire_doc, extracted)
          formula
        end

        private

        def extract_all(xml)
          opaque_list, cleaned_xml = OpaqueExtensions.extract(xml)
          {
            opaque: opaque_list,
            cleaned_xml: cleaned_xml,
            top_level: Extensions.extract_top_level(cleaned_xml),
            atom_extensions: Extensions.extract(cleaned_xml),
            group_extensions: GroupExtensions.extract(cleaned_xml),
            metadata: MetadataExtensions.extract(cleaned_xml),
            conditions: ConditionsExtensions.extract(cleaned_xml)
          }
        end

        def restore_all(formula, wire_doc, extracted)
          Extensions.restore(formula, wire_doc, extracted[:atom_extensions])
          GroupExtensions.restore(formula, wire_doc, extracted[:group_extensions])
          ConditionsExtensions.restore(formula, extracted[:conditions])
          MetadataExtensions.restore(formula, extracted[:metadata])
          Extensions.restore_top_level(formula, extracted[:top_level])
          OpaqueExtensions.restore(formula, extracted[:opaque])
        end

        def inject_atom_extensions(xml, atom_mapping)
          extensions = Extensions.collect(atom_mapping)
          Extensions.inject(xml, extensions)
        end

        def inject_molecule_extensions(xml, formula, translation)
          xml = inject_groups(xml, translation)
          inject_top_level(xml, formula)
        end

        def inject_groups(xml, translation)
          GroupExtensions.inject(xml, GroupExtensions.collect(translation.groups))
        end

        def inject_top_level(xml, formula)
          top_level = Extensions::TopLevel.collect(formula, skip_classes: NATIVELY_WIRED)
          Extensions::TopLevel.inject(xml, top_level)
        end

        def inject_opaque(xml, formula)
          OpaqueExtensions.inject(xml, formula)
        end

        def ensure_schema_registered!
          Chemicalml::Cml::Schema3.ensure_registered!
        end
      end
    end
  end
end
