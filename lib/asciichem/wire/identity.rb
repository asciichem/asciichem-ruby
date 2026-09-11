# frozen_string_literal: true

module AsciiChem
  module Wire
    # Identity wire classes: provenance and the resolved substance
    # record produced by resolver sources (TODO.impl 38+).
    class Provenance < Base
      wire_type "provenance"

      attribute :source, :string
      attribute :retrieved_at, :string
      attribute :source_version, :string
      attribute :attribution, :string
      json do
        map "source", to: :source
        map "retrievedAt", to: :retrieved_at
        map "sourceVersion", to: :source_version
        map "attribution", to: :attribution
      end
    end

    class ProvenancedIdentifier < Lutaml::Model::Serializable
      attribute :identifier, Identifier
      attribute :provenance, Provenance
      json do
        map "identifier", to: :identifier
        map "provenance", to: :provenance
      end
    end

    class ProvenancedProperty < Lutaml::Model::Serializable
      attribute :name, :string
      attribute :value, :string
      attribute :units, :string
      attribute :provenance, Provenance
      json do
        map "name", to: :name
        map "value", to: :value
        map "units", to: :units
        map "provenance", to: :provenance
      end
    end

    class SubstanceRecord < Base
      wire_type "substance-record"

      attribute :preferred_name, :string
      attribute :synonyms, :string, collection: true
      attribute :formula, :string
      attribute :molecular_weight, :float
      attribute :identifiers, ProvenancedIdentifier, collection: true
      attribute :properties, ProvenancedProperty, collection: true
      json do
        map "preferredName", to: :preferred_name
        map "synonyms", to: :synonyms
        map "formula", to: :formula
        map "molecularWeight", to: :molecular_weight
        map "identifiers", to: :identifiers
        map "properties", to: :properties
      end
    end
  end
end
