# frozen_string_literal: true

require_relative "lib/asciichem/version"

Gem::Specification.new do |spec|
  spec.name          = "asciichem"
  spec.version       = AsciiChem::VERSION
  spec.authors       = ["Ribose Inc."]
  spec.email         = ["open.source@ribose.com"]

  spec.summary       = "ASCII syntax for chemistry formulae, reactions, and structures."
  spec.description   = "AsciiChem is an ASCII syntax for representing chemical formulae, " \
                       "reactions, electron configurations, and bonds. It parses to a semantic " \
                       "model and renders to MathML, HTML, LaTeX, and SVG. Math embedding uses Plurimath."
  spec.homepage      = "https://www.asciichem.org"
  spec.license       = "BSD-2-Clause"
  spec.required_ruby_version = Gem::Requirement.new(">= 3.3.0")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/asciichem/asciichem-ruby"
  spec.metadata["changelog_uri"] = "https://github.com/asciichem/asciichem-ruby/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      f.match(%r{^(test|spec|features)/})
    end
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "chemicalml", "~> 0.2.1"
  spec.add_dependency "elkrb", "~> 1.0"
  spec.add_dependency "nokogiri", "~> 1.16"
  spec.add_dependency "parslet", "~> 2.0"
  spec.add_dependency "plurimath", "~> 0.8"
  spec.add_dependency "thor", "~> 1.3"
end
