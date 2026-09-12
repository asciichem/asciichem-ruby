# frozen_string_literal: true

require "asciichem/errors"

module AsciiChem
  # Resolution turns identifiers into substance records (TODO.v2 07
  # Layer 2; TODO.impl 38). Multi-source by design: every answering
  # source produces its own record with provenance, because the
  # citation track (TODO.v2 08) emits one bibitem per (substance,
  # source) the user chooses to cite.
  #
  # Sources are opt-in adapters that self-register (OCP, same pattern
  # as the linter checks). NC-licensed sources are never registered by
  # default — Common Chemistry ships only after the maintainer
  # sign-off recorded in TODO.v2 07.
  module Resolver
    autoload :Adapter, "asciichem/resolver/adapter"
    autoload :Cache, "asciichem/resolver/cache"
    autoload :PubChem, "asciichem/resolver/pubchem"
    autoload :Substance, "asciichem/resolver/substance"

    # Raised when sources disagree on substance identity (cross-check
    # mode). The message lists the disagreement — never hidden.
    class Conflict < AsciiChem::Error; end

    class << self
      def adapters
        @adapters ||= {}
      end

      def register(name, adapter)
        adapters[name.to_s] = adapter
      end

      def [](name)
        adapters.fetch(name.to_s)
      rescue KeyError
        raise Error, "unknown resolver source #{name.inspect} (registered: #{adapters.keys.sort.join(', ')})"
      end

      # Resolves against every opt-in source, returning one Substance
      # per source that answers (nil entries dropped). Sources answer
      # in registration order.
      def resolve_all(value:, convention:, sources: nil, fetch: nil, cache: nil, refresh: false)
        selected = sources ? Array(sources).map { |s| self[s] } : adapters.values
        selected.filter_map do |adapter_class|
          adapter = adapter_class.new
          next unless adapter.supports?(convention)

          adapter.resolve(value: value, convention: convention, fetch: fetch, cache: cache, refresh: refresh)
        end
      end

      # First answering source wins.
      def resolve(**args)
        resolve_all(**args).first
      end

      # Cross-check mode: all sources must agree on the primary key
      # (InChIKey) when more than one source provides one.
      def resolve!(**args)
        substances = resolve_all(**args)
        keys = substances.filter_map { |s| s.identifier_value("inchikey") }.uniq
        if keys.length > 1
          raise Conflict,
                "sources disagree on substance identity (InChIKeys: #{keys.join(' vs ')})"
        end
        substances.first
      end
    end

    # Open, permissive sources register eagerly; opt-in NC sources do
    # not self-register (registered manually after sign-off).
    adapters # ensure the registry exists before adapter files load
    constants.each { |c| const_get(c) unless c == :Conflict }
  end
end
