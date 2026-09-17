# frozen_string_literal: true

# relaton-bib 2 renamed the entry file (relaton_bib -> relaton/bib)
# and reworked the namespace (RelatonBib -> Relaton::Bib). The
# gemspec admits both major lines, so load whichever is resolved and
# speak to it through RelatonApi below.
begin
  require 'relaton/bib'
rescue LoadError
  require 'relaton_bib'
end

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
      'pubchem' => Profile.new(
        publisher: 'PubChem, U.S. National Library of Medicine',
        link_for: lambda do |substance|
          cid = substance.identifier_value('pubchem-cid')
          "https://pubchem.ncbi.nlm.nih.gov/compound/#{cid}" if cid
        end,
        identifier_for: lambda do |substance|
          cid = substance.identifier_value('pubchem-cid')
          "PubChem CID #{cid}" if cid
        end
      ),
      'common_chemistry' => Profile.new(
        publisher: 'CAS Common Chemistry',
        link_for: lambda do |substance|
          cas = substance.identifier_value('cas')
          "https://commonchemistry.cas.org/detail?cas_rn=#{cas}" if cas
        end,
        identifier_for: lambda do |substance|
          cas = substance.identifier_value('cas')
          "CAS RN #{cas}" if cas
        end
      )
    }.freeze

    DEFAULT_PROFILE = Profile.new(
      publisher: nil,
      link_for: ->(_substance) {},
      identifier_for: lambda do |substance|
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
        raise Error, 'substance has no provenance - resolve it first (AsciiChem::Resolver)' unless provenance&.source

        profile = PROFILES.fetch(provenance.source, DEFAULT_PROFILE)
        RelatonApi.dataset_bibitem(fields(substance, profile, provenance))
      end

      # Convenience: bibitem XML (what a document pipeline embeds).
      def to_xml(substance)
        RelatonApi.to_xml(bibitem(substance))
      end

      # The cite syntax (TODO.impl 45): a molecule annotated
      # `@cite("pubchem")` (a property annotation — the grammar needs
      # no extension) declares *which source to cite it from. This
      # resolves the molecule's identifiers and emits one bibitem per
      # cited source. Returns [[source, bibitem]] pairs; empty when the
      # molecule has no @cite annotations.
      #
      #   AsciiChem.parse('H_2O @name("water") @cite("pubchem")')
      #   AsciiChem::Citation.for_molecule(formula.nodes.first).map(&:last)
      def for_molecule(molecule, cache: nil, fetch: nil)
        sources = citation_sources(molecule)
        return [] if sources.empty?

        convention, value = lookup_key(molecule)
        unless value
          raise Error,
                'molecule carries no resolvable identifier for citation ' \
                '(annotate @cas/@inchikey/@smiles or @name)'
        end

        sources.filter_map do |source|
          substance = AsciiChem::Resolver[source].new.resolve(
            value: value, convention: convention, cache: cache, fetch: fetch
          )
          next unless substance

          [source, bibitem(substance)]
        end
      end

      private

      # The version-independent field payload: one hash describing the
      # citation, translated to Relaton objects by RelatonApi.
      def fields(substance, profile, provenance)
        publisher = profile.publisher || provenance.source
        {
          type: 'dataset',
          title: "#{title_base(substance)} - #{publisher} substance record",
          docid: { id: profile.identifier_for.call(substance) || "#{provenance.source} substance",
                   type: provenance.source },
          publisher: publisher,
          accessed_on: accessed_on(provenance),
          link: profile.link_for.call(substance),
          keywords: substance.identifiers.map { |i| "#{i.convention}=#{i.value}" }
        }
      end

      # The property annotation whose title is "cite": values are the
      # source names to cite from.
      def citation_sources(molecule)
        molecule.properties
                .select { |p| p.title == 'cite' && p.value }
                .map(&:value)
      end

      # First identifier the resolver can look up by, in preference
      # order: unambiguous registry keys before names.
      def lookup_key(molecule)
        identifier = molecule.identifiers.find { |i| %w[cas inchikey pubchem-cid].include?(i.convention) }
        return [identifier.convention, identifier.value] if identifier

        name = molecule.names.first
        return ['name', name.content] if name

        nil
      end

      def title_base(substance)
        substance.preferred_name || substance.identifier_value('cas') ||
          substance.identifier_value('inchikey') || 'Substance'
      end

      def accessed_on(provenance)
        return provenance.retrieved_at[0, 10] if provenance.retrieved_at

        Time.now.utc.strftime('%Y-%m-%d')
      end
    end

    # The relaton-bib version seam. Both major lines accept the same
    # field hash (see Citation#fields) and serialize through their own
    # API; the rest of the citation track stays version-agnostic.
    # Adding a future major = one more module here (OCP).
    module RelatonApi
      module_function

      def dataset_bibitem(fields)
        (defined?(::Relaton::Bib) ? V2 : V1).build(fields)
      end

      def to_xml(item)
        item.to_xml
      end

      # relaton-bib 1: RelatonBib::* with hash-argument constructors.
      module V1
        module_function

        def build(fields)
          RelatonBib::BibliographicItem.new(
            type: fields[:type],
            title: [{ type: 'main', content: fields[:title] }],
            docid: [RelatonBib::DocumentIdentifier.new(id: fields[:docid][:id],
                                                       type: fields[:docid][:type])],
            contributor: [{ entity: RelatonBib::Organization.new(name: fields[:publisher]),
                            role: [{ type: 'publisher' }] }],
            date: [{ type: 'accessed', on: fields[:accessed_on] }],
            link: fields[:link] ? [{ type: 'src', content: fields[:link] }] : [],
            keyword: fields[:keywords]
          )
        end
      end

      # relaton-bib 2: Relaton::Bib::* typed models (lutaml-model).
      # Date's XML <on> element maps to the Ruby `at` attribute;
      # keywords carry their text in a nested vocab LocalizedString;
      # links are source Uri entries serializing to <uri type="src">.
      module V2
        module_function

        def build(fields)
          Relaton::Bib::ItemData.new(
            type: fields[:type],
            title: [Relaton::Bib::Title.new(type: 'main', content: fields[:title])],
            docidentifier: [docidentifier(fields[:docid])],
            contributor: [contributor(fields[:publisher])],
            date: [Relaton::Bib::Date.new(type: 'accessed', at: fields[:accessed_on])],
            source: fields[:link] ? [Relaton::Bib::Uri.new(type: 'src', content: fields[:link])] : [],
            keyword: fields[:keywords].map { |text| keyword(text) }
          )
        end

        def docidentifier(docid)
          Relaton::Bib::Docidentifier.new(type: docid[:type], content: docid[:id])
        end

        def contributor(publisher)
          Relaton::Bib::Contributor.new(
            organization: Relaton::Bib::Organization.new(
              name: [Relaton::Bib::TypedLocalizedString.new(content: publisher)]
            ),
            role: [Relaton::Bib::Contributor::Role.new(type: 'publisher')]
          )
        end

        def keyword(text)
          Relaton::Bib::Keyword.new(
            vocab: Relaton::Bib::LocalizedString.new(content: text)
          )
        end
      end
    end
    private_constant :RelatonApi
  end
end
