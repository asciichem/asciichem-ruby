# Changelog

All notable changes to AsciiChem are documented here.
This project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Initial gem scaffold: autoload tree, version, errors.
- Core model: `Formula`, `Atom`, `Molecule`, `Group`, `Bond`, `Reaction`,
  `ElectronConfiguration`, `EmbeddedMath`, `Text`.
- Parslet parser and transform for v1 constructs.
- Formatters: MathML and Text (round-trip).
- Thor-based CLI: `convert`, `roundtrip`, `version`.
- Comprehensive RSpec suite with round-trip conformance.

[Unreleased]: https://github.com/asciichem/asciichem-ruby/commits/main
