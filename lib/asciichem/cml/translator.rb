# frozen_string_literal: true

require "chemicalml"

module AsciiChem
  module Cml
    # Thin composition of the AsciiChem <-> canonical adapter
    # (`AsciiChem::ModelAdapter`) and the canonical <-> CML adapter
    # (`Chemicalml::Cml::Translator`). Owns no chemistry logic — just
    # wiring, the schema-registration dance that chemicalml requires
    # on first use, and the aci: extension namespace side-channel
    # that carries AsciiChem-specific fields through CML round-trip.
    class Translator
      class << self
        # AsciiChem::Model::Formula -> CML XML string.
        def from_asciichem(formula)
          ensure_schema_registered!
          translation = AsciiChem::ModelAdapter.to_canonical_with_mapping(formula)
          wire_doc = Chemicalml::Cml::Translator.from_canonical(translation.document)
          xml = wire_doc.to_xml
          xml = inject_atom_extensions(xml, translation.atom_mapping)
          xml = inject_group_extensions(xml, translation.groups)
          inject_top_level_extensions(xml, formula)
        end

        # CML XML string -> AsciiChem::Model::Formula.
        def to_asciichem(xml)
          ensure_schema_registered!
          top_level = Extensions.extract_top_level(xml)
          atom_extensions = Extensions.extract(xml)
          group_extensions = GroupExtensions.extract(xml)
          wire_doc = Chemicalml::Cml::Document.from_xml(xml)
          canonical = Chemicalml::Cml::Translator.to_canonical(wire_doc)
          formula = AsciiChem::ModelAdapter.from_canonical(canonical)
          Extensions.restore(formula, canonical, atom_extensions)
          GroupExtensions.restore(formula, canonical, group_extensions)
          Extensions.restore_top_level(formula, top_level)
          formula
        end

        private

        def inject_atom_extensions(xml, atom_mapping)
          extensions = Extensions.collect(atom_mapping)
          Extensions.inject(xml, extensions)
        end

        def inject_group_extensions(xml, groups_by_molecule)
          collected = GroupExtensions.collect(groups_by_molecule)
          GroupExtensions.inject(xml, collected)
        end

        def inject_top_level_extensions(xml, formula)
          top_level = Extensions.collect_top_level(formula)
          Extensions.inject_top_level(xml, top_level)
        end

        # chemicalml registers wire classes into a lutaml-model
        # TypeRegistry on first use. The registry call is idempotent
        # (guarded by `@models_registered`) but must run before any
        # `from_xml` so element types like `molecule` and `atom` are
        # resolvable.
        def ensure_schema_registered!
          Chemicalml::Cml::Schema3.ensure_registered!
        end
      end
    end
  end
end
