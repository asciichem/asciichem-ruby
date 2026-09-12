# frozen_string_literal: true

module AsciiChem
  module Resolver
    # A source adapter. Subclasses register themselves:
    #
    #   class MySource < Adapter
    #     source_name :mysource
    #     supports "name", "inchikey"
    #     def fetch_record(...); end
    #   end
    #
    # `resolve` handles caching around `fetch_record`; the transport
    # (`fetch`) is injectable so specs run offline.
    class Adapter
      class << self
        # Declares the source name and registers the adapter (called
        # from the class body — `inherited` fires before the body
        # runs, so it cannot see the subclass configuration).
        def source_name(name = nil)
          return @source_name if name.nil?

          @source_name = name.to_s
          AsciiChem::Resolver.register(@source_name, self)
        end

        def supports(*conventions)
          @supported_conventions = conventions.map(&:to_s)
        end

        def supported_conventions
          @supported_conventions || []
        end
      end

      def supports?(convention)
        self.class.supported_conventions.include?(convention.to_s)
      end

      # Cache-aware resolution. `fetch` must answer #get(url) -> body
      # String (NetFetch by default; specs inject recorded responses).
      def resolve(value:, convention:, fetch: nil, cache: nil, refresh: false)
        cache ||= Cache.default
        fetch ||= NetFetch.new
        key = cache.key_for(self.class.source_name, convention, value)

        unless refresh
          cached = cache.read(key)
          return cached if cached
        end

        substance = fetch_record(value: value, convention: convention, fetch: fetch)
          .tap { |s| s&.identifiers&.each { |i| i.provenance ||= default_provenance } }
        cache.write(key, substance) if substance
        substance
      end

      # Not-found is nil, not an error — sources legitimately answer
      # "unknown substance" during multi-source resolution.
      def fetch_record(**)
        raise NotImplementedError
      end

      def default_provenance
        Provenance.new(
          source: self.class.source_name,
          retrieved_at: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
          attribution: attribution
        )
      end

      def attribution
        nil
      end
    end

    # Minimal stdlib HTTP transport. No runtime gem dependencies.
    class NetFetch
      def get(url, limit = 3)
        raise Error, "too many redirects" if limit.zero?

        uri = URI(url)
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                                  open_timeout: 5, read_timeout: 10) do |http|
          http.request(Net::HTTP::Get.new(uri.request_uri, "User-Agent" => "asciichem-resolver"))
        end

        case response
        when Net::HTTPSuccess then response.body
        when Net::HTTPRedirection then get(URI.join(uri, response["location"]).to_s, limit - 1)
        when Net::HTTPNotFound then nil
        else
          raise Error, "HTTP #{response.code}: #{response.message}"
        end
      end
    end
  end
end
