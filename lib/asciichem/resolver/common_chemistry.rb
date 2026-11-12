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
    #
    # API access: CAS key-gated the API (401 without a key; request
    # one at cas.org/services/commonchemistry-api). The access email
    # defines the contract: GET /direct-api/detail with the token as
    # the X-API-KEY header plus x-origin and accept headers. The key
    # comes per instance (`api_key:`), from
    # COMMON_CHEMISTRY_API_KEY, or from
    # ~/.config/cas-common-chemistry-api.key (the token's stored
    # location). Tokens are personal and expire after 12 months
    # (CAS emails a renewal notice). Without a key, live lookups
    # answer 401 and the resolver skips this source; seeded caches
    # keep working.
    class CommonChemistry < Adapter
      source_name :common_chemistry
      supports "cas"

      BASE = "https://commonchemistry.cas.org/direct-api/detail"
      ORIGIN = "https://commonchemistry.cas.org/api-overview"
      KEY_FILE = File.expand_path("~/.config/cas-common-chemistry-api.key")

      attr_reader :api_key

      # Explicit nil means no key; the env/file lookup runs only when
      # the argument is omitted.
      def initialize(api_key: default_api_key)
        super()
        @api_key = api_key
      end

      def fetch_record(value:, convention:, fetch:)
        headers = {
          "Accept" => "application/json",
          "x-origin" => ORIGIN
        }
        headers["X-API-KEY"] = api_key if api_key
        body = fetch.get("#{BASE}?cas_rn=#{CGI.escape(value.to_s)}", headers)
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

      def default_api_key
        ENV.fetch("COMMON_CHEMISTRY_API_KEY", nil) ||
          (File.read(KEY_FILE).strip if File.readable?(KEY_FILE))
      end

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
