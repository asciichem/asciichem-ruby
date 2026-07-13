# frozen_string_literal: true

source "https://rubygems.org"

# Use the local chemml checkout during development so asciichem-ruby
# tracks uncommitted chemml changes. The gemspec declares the released
# dependency.
gem "chemml", path: File.expand_path("../../lutaml/chemml", __dir__)

gemspec

group :development do
  gem "benchmark", "~> 0.4"
  gem "benchmark-ips", "~> 2.14", require: false
  gem "rake", "~> 13.2"
  gem "rspec", "~> 3.13"
  gem "rubocop", "~> 1.66", require: false
  gem "simplecov", "~> 0.22", require: false
end
