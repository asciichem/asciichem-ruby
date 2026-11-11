# frozen_string_literal: true

require "cgi"
require "json"

module AsciiChem
  module Resolver
    # CAS Common Chemistry source adapter (TODO.impl 40; TODO.v2 07).
    #
    # License posture (maintainer decision 2026-11-11): Common
    # Chemistry data is CC BY-NC 4.0 — acceptable to enable by
    # default; every result carries the required attribution, and the
    # citation track carries it into rendered documents. Documents
    # that must stay NC-free limit sources with the
    # `asciichem-sources` attribute (metanorma-plugin-asciichem) or
    # `Resolver.resolve(sources:)`.
    class CommonChemistry < Adapter
      source_name :common_chemistry
      supports "cas"

      BASE = "https://commonchemistry.cas.org/api/detail"

      def fetch_record(value:, convention:, fetch:)
        body = fetch.get("#{BASE}?cas_rn=#{CGI.escape(value.to_s)}")
        return nil unless body

        data = JSON.parse(body)
        return nil if data.empty?

        substance_from(data)
      rescue JSON::ParserError => e
        raise Error, "common_chemistry returned malformed JSON: #{e.message}"
      end

      def attribution
        "CAS Common Chemistry (CC BY-NC 4.0)"
      end

      private

      def substance_from(data)
        provenance = default_provenance
        identifiers = [Identifier.new(value: data["rn"], convention: "cas",
                                      provenance: provenance)]
        add_identifier(identifiers, data, "inchikey", "inchikey", provenance)
        add_identifier(identifiers, data, "smiles", "canonical-smiles", provenance)
        add_identifier(identifiers, data, "inchi", "inchi", provenance)
        add_identifier(identifiers, data, "iupacName", "iupac-name", provenance)

        Substance.new(
          preferred_name: data["name"],
          formula: data["formula"],
          identifiers: identifiers,
          properties: [
            Property.new(name: "molecular-formula", value: data["formula"], provenance: provenance),
            Property.new(name: "molecular-weight", value: data["molecularMass"]&.to_s,
                         units: "g/mol", provenance: provenance)
          ].compact,
          # Best effort within the supported SMILES subset; the SMILES
          # stays as an identifier when stereo keeps it out.
          structure: parse_structure(data["smiles"])
        )
      end

      def add_identifier(list, data, key, convention, provenance)
        return unless data[key]

        list << Identifier.new(value: data[key], convention: convention,
                               provenance: provenance)
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
