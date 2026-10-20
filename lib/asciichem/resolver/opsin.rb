# frozen_string_literal: true

require 'cgi'
require 'json'
require 'net/https'
require 'uri'

module AsciiChem
  module Resolver
    # OPSIN source adapter (TODO.v2/13 item 3): IUPAC name → structure
    # — name-to-structure perception for systematic names, the piece
    # PubChem's name lookup cannot do (PubChem indexes a curated name
    # list; OPSIN *derives* the structure from any systematic IUPAC
    # name). Uses the public OPSIN web service
    # (https://opsin.ch.cam.ac.uk), which answers with CML or SMILES.
    #
    # Citation profile: publisher University of Cambridge Centre for
    # Molecular Informatics; per-access retrievedAt provenance.
    class Opsin < Adapter
      source_name :opsin
      # Derivation only: 'name' is the curated-lookup convention
      # (PubChem/Common Chemistry). OPSIN DERIVES structures from
      # systematic names - reachable via 'iupac-name' so it can
      # never preempt a lookup source.
      supports 'iupac-name'

      BASE = 'https://opsin.ch.cam.ac.uk/opsin'
      private_constant :BASE

      def fetch_record(value:, convention: nil, fetch:)
        body = fetch.get("#{BASE}/#{CGI.escape(value.to_s)}.smiles")
        return nil unless body

        substance_from(body.strip)
      rescue StandardError => e
        raise Error, "opsin request failed: #{e.message}"
      end

      def attribution
        'OPSIN, University of Cambridge Centre for Molecular Informatics'
      end

      private

      def substance_from(smiles)
        return nil if smiles.empty?

        provenance = default_provenance
        Substance.new(
          preferred_name: nil,
          identifiers: [Identifier.new(value: smiles, convention: 'canonical-smiles',
                                       provenance: provenance)],
          properties: [],
          structure: parse_structure(smiles)
        )
      end

      # OPSIN answers SMILES that may use features outside the
      # supported subset (wildcards, exotic stereo); then the SMILES
      # stays as an identifier and structure is nil — no silent loss.
      def parse_structure(smiles)
        AsciiChem.parse_smiles(smiles).nodes.first
      rescue AsciiChem::ParseError
        nil
      end
    end
  end
end
