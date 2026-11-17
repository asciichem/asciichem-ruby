# frozen_string_literal: true

source "https://rubygems.org"

gemspec

group :development do
  gem "parsanol", "~> 1.5.0"
  # regexp_parser 2.13.2 (published today) removed `implements`,
  # which json_schemer's ecma_regexp still calls — every spec fails
  # to load. Capped under the removal until json_schemer adapts (the
  # lockfile is ignored here, so this constraint is the only control).
  gem "regexp_parser", "~> 2.12.0"
  gem "benchmark", "~> 0.4"
  gem "benchmark-ips", "~> 2.14", require: false
  gem "rake", "~> 13.2"
  gem "rspec", "~> 3.13"
  gem "rubocop", "~> 1.66", require: false
  gem "simplecov", "~> 0.22", require: false
end
