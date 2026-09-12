# frozen_string_literal: true

module AsciiChem
  module Resolver
    # Domain value objects for resolution results. These are data
    # carriers; (de)serialization to the canonical wire form goes
    # through the lutaml-model Wire classes only.
    Provenance = Struct.new(:source, :retrieved_at, :source_version, :attribution, keyword_init: true)
    Identifier = Struct.new(:value, :convention, :provenance, keyword_init: true)
    Property = Struct.new(:name, :value, :units, :provenance, keyword_init: true)

    # A resolved substance: identity + provenance + best-effort
    # structure. `structure` is a Model::Molecule when the source's
    # SMILES parses within the supported subset; otherwise nil and the
    # SMILES stays available as an identifier — nothing is dropped.
    class Substance
      attr_reader :preferred_name, :synonyms, :formula, :molecular_weight,
                  :identifiers, :properties, :structure

      def initialize(preferred_name: nil, synonyms: [], formula: nil,
                     molecular_weight: nil, identifiers: [], properties: [],
                     structure: nil)
        @preferred_name = preferred_name
        @synonyms = synonyms
        @formula = formula
        @molecular_weight = molecular_weight
        @identifiers = identifiers
        @properties = properties
        @structure = structure
      end

      def identifier_value(convention)
        identifiers.find { |i| i.convention == convention }&.value
      end

      def provenance
        identifiers.first&.provenance
      end

      # Canonical wire form (asciichem-model v1 substance-record).
      def to_model_json
        Wire::SubstanceRecord.new(
          type: "substance-record",
          preferred_name: preferred_name,
          synonyms: synonyms,
          formula: formula,
          molecular_weight: molecular_weight,
          identifiers: identifiers.map do |i|
            Wire::ProvenancedIdentifier.new(
              identifier: Wire::Identifier.new(type: "identifier", value: i.value, convention: i.convention),
              provenance: provenance_wire(i.provenance)
            )
          end,
          properties: properties.map do |p|
            Wire::ProvenancedProperty.new(
              name: p.name, value: p.value, units: p.units,
              provenance: provenance_wire(p.provenance)
            )
          end
        ).to_json
      end

      # Rebuilds a Substance from the wire form (the cache path).
      def self.from_model_json(json)
        wire = Wire::SubstanceRecord.from_json(json)
        new(
          preferred_name: wire.preferred_name,
          synonyms: Array(wire.synonyms),
          formula: wire.formula,
          molecular_weight: wire.molecular_weight,
          identifiers: Array(wire.identifiers).map do |pi|
            Identifier.new(
              value: pi.identifier&.value,
              convention: pi.identifier&.convention,
              provenance: provenance_domain(pi.provenance)
            )
          end,
          properties: Array(wire.properties).map do |p|
            Property.new(name: p.name, value: p.value, units: p.units,
                         provenance: provenance_domain(p.provenance))
          end
        )
      end

      def self.provenance_domain(wire)
        return nil unless wire

        Provenance.new(source: wire.source, retrieved_at: wire.retrieved_at,
                       source_version: wire.source_version, attribution: wire.attribution)
      end

      private

      def provenance_wire(p)
        return nil unless p

        Wire::Provenance.new(
          type: "provenance",
          source: p.source, retrieved_at: p.retrieved_at,
          source_version: p.source_version, attribution: p.attribution
        )
      end
    end
  end
end
