# frozen_string_literal: true

module AsciiChem
  # Adapter between AsciiChem::Model (the chemistry-semantic tree the
  # text parser produces) and Chemicalml::Model (the format-agnostic
  # canonical hub every chemistry interchange format speaks).
  #
  # The adapter is bidirectional and pure — no I/O, no wire format
  # concerns. Composed with `Chemicalml::Cml::Translator` it forms the
  # AsciiChem <-> CML pipeline:
  #
  #   AsciiChem::Model <-> ModelAdapter <-> Chemicalml::Model
  #                                                ^
  #                                                |
  #                                       Chemicalml::Cml::Translator
  #                                                |
  #                                                v
  #                                       Chemicalml::Cml::* (wire)
  #
  # Adding a new field to either model means updating this adapter's
  # mapping rules; the parsers, formatters, and wire classes stay
  # independent.
  module ModelAdapter
    autoload :ToCanonical, "asciichem/model_adapter/to_canonical"
    autoload :FromCanonical, "asciichem/model_adapter/from_canonical"

    # Result of a translation that also exposes the per-atom mapping
    # (canonical_atom_id => AsciiChem::Model::Atom) and the per-molecule
    # group structure (molecule_id => Array<GroupRecord>). Used by
    # callers that need to track per-atom side data through the
    # canonical pipeline (e.g. the CML extension namespace).
    Translation = Struct.new(:document, :atom_mapping, :groups, keyword_init: true)

    def self.to_canonical(formula)
      ToCanonical.new(formula).build
    end

    # Returns the canonical document plus the per-atom mapping and
    # per-molecule group structure. Use this when you need to know
    # which canonical atom corresponds to which AsciiChem::Model::Atom
    # or which atoms were originally grouped (e.g. for extension data).
    def self.to_canonical_with_mapping(formula)
      builder = ToCanonical.new(formula)
      document = builder.build
      Translation.new(
        document: document,
        atom_mapping: builder.atom_mapping,
        groups: builder.groups
      )
    end

    def self.from_canonical(document)
      FromCanonical.new(document).build
    end
  end
end
