# frozen_string_literal: true

source "https://rubygems.org"

gemspec

group :development do
  gem "parsanol", "~> 1.5.0"
  # Capped off 2.5.0: it calls regexp_parser's `implements`, which
  # regexp_parser 2.13.2 removed (the suite fails to load).
  gem "json_schemer", "~> 2.4.0"
  gem "benchmark", "~> 0.4"
  gem "benchmark-ips", "~> 2.14", require: false
  gem "rake", "~> 13.2"
  gem "rspec", "~> 3.13"
  gem "rubocop", "~> 1.66", require: false
  gem "simplecov", "~> 0.22", require: false
end
