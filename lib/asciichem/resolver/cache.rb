# frozen_string_literal: true

require "digest"
require "json"
require "fileutils"

module AsciiChem
  module Resolver
    # Resolution cache in the USER cache dir (never the gem install
    # dir): entries carry source, retrieved-at, attribution, TTL.
    class Cache
      DEFAULT_TTL = 7 * 24 * 60 * 60 # chemistry identifiers are stable

      attr_reader :dir

      def self.default_dir
        base = ENV.fetch("XDG_CACHE_HOME", nil) || File.join(Dir.home, ".cache")
        File.join(base, "asciichem", "resolver")
      end

      def initialize(dir: self.class.default_dir, ttl: DEFAULT_TTL)
        @dir = dir
        @ttl = ttl
      end

      def self.default
        @default ||= new
      end

      def key_for(source, convention, value)
        Digest::SHA256.hexdigest("#{source}:#{convention}:#{value}")
      end

      def read(key)
        path = File.join(dir, "#{key}.json")
        return nil unless File.file?(path)

        entry = JSON.parse(File.read(path))
        return nil if stale?(entry)

        Substance.from_model_json(JSON.generate(entry["substance"]))
      rescue JSON::ParserError, StandardError
        nil
      end

      def write(key, substance)
        FileUtils.mkdir_p(dir)
        File.write(File.join(dir, "#{key}.json"), JSON.pretty_generate(
          cached_at: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
          ttl_seconds: @ttl,
          substance: JSON.parse(substance.to_model_json)
        ))
        substance
      end

      private

      def stale?(entry)
        cached_at = Time.parse(entry["cached_at"]) rescue nil
        return true unless cached_at

        Time.now.utc - cached_at > entry.fetch("ttl_seconds", @ttl)
      end
    end
  end
end
