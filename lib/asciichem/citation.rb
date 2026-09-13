# frozen_string_literal: true

require "relaton_bib"

module AsciiChem
  # Citation track (TODO.v2 08; TODO.impl 44): a bibitem is a function
  # of (substance, source) — one dataset-type Relaton bibitem per
  # source the user chooses to cite, because two databases agreeing on
  # a substance are still two different documents.
  #
  # Source-specific fields (link shape, publisher string, docidentifier
  # scheme) live in PROFILES; adding a source is one entry (OCP).
  module Citation
    # Source-specific citation profile. Default fields fall back to
    # the substance's provenance.
    Profile = Struct.new(:publisher, :link_for, :identifier_for, keyword_init: true)

    PROFILES = {
      "pubchem" => Profile.new(
        publisher: "PubChem, U.S. National Library of Medicine",
        link_for: ->(substance) do
          cid = substance.identifier_value("pubchem-cid")
          "https://pubchem.ncbi.nlm.nih.gov/compound/#{cid}" if cid
        end,
        identifier_for: ->(substance) do
          cid = substance.identifier_value("pubchem-cid")
          "PubChem CID #{cid}" if cid
        end
      ),
      "common_chemistry" => Profile.new(
        publisher: "CAS Common Chemistry",
        link_for: ->(substance) do
          cas = substance.identifier_value("cas")
          "https://commonchemistry.cas.org/detail?cas_rn=#{cas}" if cas
        end,
        identifier_for: ->(substance) do
          cas = substance.identifier_value("cas")
          "CAS RN #{cas}" if cas
        end
      )
    }.freeze

    DEFAULT_PROFILE = Profile.new(
      publisher: nil,
      link_for: ->(_substance) { nil },
      identifier_for: ->(substance) do
        key = substance.identifiers.first
        "#{key.convention}: #{key.value}" if key
      end
    ).freeze
    private_constant :DEFAULT_PROFILE

    class << self
      # Builds a Relaton dataset-type bibitem for the substance as
      # cited from its recorded source. Raises when the substance
      # carries no provenance (hand-built, not resolved).
      def bibitem(substance)
        provenance = substance.provenance
        unless provenance&.source
          raise Error, "substance has no provenance - resolve it first (AsciiChem::Resolver)"
        end

        profile = PROFILES.fetch(provenance.source, DEFAULT_PROFILE)
        RelatonBib::BibliographicItem.new(
          type: "dataset",
          title: [{ type: "main",
                    content: "#{title_base(substance)} - #{profile.publisher || provenance.source} substance record" }],
          docid: [RelatonBib::DocumentIdentifier.new(
                    id: profile.identifier_for.call(substance) || "#{provenance.source} substance",
                    type: provenance.source)],
          contributor: [{ entity: RelatonBib::Organization.new(name: profile.publisher || provenance.source),
                          role: [{ type: "publisher" }] }],
          date: [{ type: "accessed", on: accessed_on(provenance) }],
          link: [{ type: "src", content: profile.link_for.call(substance) }].compact,
          keyword: substance.identifiers.map { |i| "#{i.convention}=#{i.value}" }
        )
      end

      # Convenience: bibitem XML (what a document pipeline embeds).
      def to_xml(substance)
        bibitem(substance).to_xml
      end

      private

      def title_base(substance)
        substance.preferred_name || substance.identifier_value("cas") ||
          substance.identifier_value("inchikey") || "Substance"
      end

      def accessed_on(provenance)
        return provenance.retrieved_at[0, 10] if provenance.retrieved_at

        Time.now.utc.strftime("%Y-%m-%d")
      end
    end
  end
end
