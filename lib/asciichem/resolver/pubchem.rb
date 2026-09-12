# frozen_string_literal: true

require "cgi"
require "json"
require "net/https"
require "uri"

module AsciiChem
  module Resolver
    # PubChem source adapter (TODO.impl 39; TODO.v2 07 Layer 2).
    # PubChem is the default source: keyless PUG-REST, permissive
    # terms, and the bulk mirror of Common Chemistry's validated CAS
    # RNs (CAS numbers are indexed as names). Politeness: one request
    # per resolution, 5/10s timeouts, no retries — PubChem asks for
    # max 5 requests/second.
    #
    # Citation profile (TODO.v2 08): publisher NCBI, per-access
    # versioning (retrievedAt provenance), compound link
    # https://pubchem.ncbi.nlm.nih.gov/compound/{cid}.
    class PubChem < Adapter
      source_name :pubchem
      supports "name", "cas", "pubchem-cid", "inchikey", "inchi", "smiles", "canonical-smiles"

      BASE = "https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound"
      PROPERTIES = %w[CanonicalSMILES IsomericSMILES MolecularFormula
                      MolecularWeight IUPACName InChI InChIKey].freeze
      private_constant :BASE, :PROPERTIES

      def fetch_record(value:, convention:, fetch:)
        body = fetch.get(url_for(value, convention))
        return nil unless body

        props = JSON.parse(body).dig("PropertyTable", "Properties", 0)
        return nil unless props

        substance_from(props)
      rescue JSON::ParserError => e
        raise Error, "pubchem returned malformed JSON: #{e.message}"
      end

      def attribution
        "PubChem, U.S. National Library of Medicine"
      end

      private

      # CAS numbers are indexed as PubChem names (Common Chemistry
      # mirror), so both map to the name namespace.
      def url_for(value, convention)
        namespace = { "name" => "name", "cas" => "name", "pubchem-cid" => "cid",
                      "inchikey" => "inchikey", "inchi" => "inchi",
                      "smiles" => "smiles", "canonical-smiles" => "smiles" }.fetch(convention.to_s)
        "#{BASE}/#{namespace}/#{CGI.escape(value.to_s)}/property/#{PROPERTIES.join(',')}/JSON"
      end

      def substance_from(props)
        provenance = default_provenance
        identifiers = []
        identifiers << Identifier.new(value: props["CID"].to_s, convention: "pubchem-cid", provenance: provenance) if props["CID"]
        add_identifier(identifiers, props, "InChIKey", "inchikey", provenance)
        add_identifier(identifiers, props, "InChI", "inchi", provenance)
        add_identifier(identifiers, props, "CanonicalSMILES", "canonical-smiles", provenance)

        Substance.new(
          preferred_name: props["IUPACName"],
          formula: props["MolecularFormula"],
          molecular_weight: props["MolecularWeight"]&.to_f,
          identifiers: identifiers,
          properties: [
            Property.new(name: "molecular-formula", value: props["MolecularFormula"], provenance: provenance),
            Property.new(name: "molecular-weight", value: props["MolecularWeight"],
                         units: "g/mol", provenance: provenance)
          ].compact,
          # Best effort: PubChem canonical SMILES may use constructs
          # outside the supported subset (stereo); then the SMILES
          # stays as an identifier and structure is nil — no silent loss.
          structure: parse_structure(props["CanonicalSMILES"])
        )
      end

      def add_identifier(list, props, key, convention, provenance)
        return unless props[key]

        list << Identifier.new(value: props[key], convention: convention, provenance: provenance)
      end

      def parse_structure(smiles)
        return nil unless smiles

        AsciiChem.parse_smiles(smiles).nodes.first
      rescue AsciiChem::ParseError
        nil
      end
    end
  end
end
