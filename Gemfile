# frozen_string_literal: true

source "https://rubygems.org"

# Use the local chemicalml checkout when available (dev); fall back to
# the GitHub repo on CI / other machines. The gemspec declares the
# released dependency.
local_chemicalml = File.expand_path("../../lutaml/chemicalml", __dir__)
if File.directory?(local_chemicalml)
  gem "chemicalml", path: local_chemicalml
else
  gem "chemicalml", github: "lutaml/chemicalml"
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
