# frozen_string_literal: true

source "https://rubygems.org"

# Use the local chemml checkout when available (dev); fall back to
# the GitHub repo on CI / other machines. The gemspec declares the
# released dependency.
local_chemml = File.expand_path("../../lutaml/chemml", __dir__)
if File.directory?(local_chemml)
  gem "chemml", path: local_chemml
else
  gem "chemml", github: "lutaml/chemml"
end

gemspec

group :development do
  gem "benchmark", "~> 0.4"
  gem "benchmark-ips", "~> 2.14", require: false
  gem "rake", "~> 13.2"
  gem "rspec", "~> 3.13"
  gem "rubocop", "~> 1.66", require: false
  gem "simplecov", "~> 0.22", require: false
end
