# Changelog

All notable changes to AsciiChem are documented here.
This project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.6.0] - 2026-07-20

### Added
- `Model::OpaqueCml` node + `Cml::OpaqueExtensions` module: preserve
  unknown CML elements through round-trip as opaque blobs.
- `Linter::ChargeBalanceCheck`: validates charge conservation in
  reactions (parallel to BalanceCheck's atom conservation).
- `Linter::CrystalSanityCheck`, `ZMatrixReferenceCheck`,
  `SpectrumPeakCheck`: validate cell parameters, ZMatrix references,
  and spectrum peak data.
- `Molecule#atom_count`: total atom count recursing through groups
  and nested molecules with subscripts and multiplicities applied.
- `Model::Molecule::Property`, `Meta`, `Label`, `Formula` Structs
  replace Hash-with-magic-keys fields.
- `Model::Spectrum::Peak`, `Calculation::Property`, `Mechanism::Step`
  Structs replace Hash-with-magic-keys fields.
- Formatter visit methods for `Crystal`, `Spectrum`, `Calculation`,
  `ZMatrix`, `Mechanism`, `OpaqueCml` across MathML, HTML, LaTeX, SVG.
- CLI smoke coverage for beyond-formulas constructs.
- Fuzz corpus files 16-20 (crystal, spectrum, calculation, zmatrix,
  mechanism).
- Benchmark cases for beyond-formulas constructs.

### Changed
- `Cml::Extensions` split into `Extensions::AtomAttributes` and
  `Extensions::TopLevel` sub-modules; facade preserves public API.
- `Cml::MetadataExtensions` and `Cml::ConditionsExtensions` extracted
  from inline Translator code as parallel extension channels.
- `Cml::ID_PREFIXES` is the single source of truth for canonical ID
  prefixes (atom/bond/molecule/reaction/group).
- `Extensions.ensure_namespace(root)` shared helper replaces six
  duplicated `namespace_declared?` / `ensure_namespace` methods.
- `Model::Bond` owns `CML_ORDER_CODES`, `KIND_BY_CML_ORDER`,
  `CML_STEREO_CODES` (was duplicated across adapter directions).
- `Model::Group` owns `BRACKETS` with `{open, close, wire}` attrs.
- `Model::Reaction` owns `ARROW_BY_WIRE` inverse map.
- `Model::Crystal` owns `CELL_PARAMS`, `LENGTH_FIELDS`, `ANGLE_FIELDS`,
  `CELL_LABELS`, `#each_cell_param(format)` as single source for cell
  parameter labels across formatters.
- `Extensions::TopLevel::Handler.text_round_trip` and
  `.source_with_wrapper` factory methods eliminate duplicate lambdas
  across 8 handlers.
- `Transform::BuilderHelpers` shared module included by all 5 builder
  classes.
- `Linter::Base.register(:name)` pattern — adding a check is one new
  file + one autoload entry.

### Fixed
- Empty body braces (`crystal[x]{}`, `spectrum[nmr](){}`, etc.) now
  parse correctly for all 5 beyond-formulas constructs. Root cause:
  parslet represents zero-match `.repeat` as `[]` not `""`.
- Cascade step conditions (`A ->[c1] B ->[c2] C`) now survive CML
  round-trip. Previously the inline translator code only walked
  top-level reactions.

## [0.5.1] - 2026-07-16

### Added
- CML round-trip for all five beyond-formulas constructs via aci:
  namespace extension elements.

## [0.5.0] - 2026-07-16

### Added
- Phase 5: reaction mechanism syntax (`mechanism{step1: A -> B;
  spectator: Na+}`).

## [0.4.1] - 2026-07-16

### Added
- Phase 3: computational chemistry results (`calc(method/basis){...}`).
- Phase 4: Z-Matrix internal coordinates (`zmatrix{C1; H2 C1 1.09; ...}`).

## [0.4.0] - 2026-07-16

### Added
- Phase 1: crystallography syntax (`crystal[NaCl](a=...,sg=...){...}`).
- Phase 2: spectroscopy syntax (`spectrum[nmr](type=1H,...){...}`).

## [0.3.4] - 2026-07-16

### Added
- Spin multiplicity (`C@m(2)`), atom title (`C@t("alpha")`), and
  fractional coordinates (`C@f(0.5,0.5,0.5)`) syntax.

## [0.3.3] - 2026-07-16

### Fixed
- Property and metadata CML round-trip for chemicalml 0.2.1.

## [0.3.2] - 2026-07-16

### Added
- Reaction conditions CML round-trip via aci: attributes.

## [0.3.1] - 2026-07-16

### Changed
- Adapted to chemicalml 0.2.1 (wire classes ARE the model).

## [0.3.0] - 2026-07-15

### Added
- Full CML support via chemicalml gem.
- aci: extension namespace for fields CML doesn't natively carry.
- New syntax: spin multiplicity, atom titles, fractional coordinates,
  molecule annotations (`@name`, `@inchi`, `@meta`, `@formula`,
  `@label`, `@mw`, `@title`).
- Group preservation through CML round-trip via `<aci:group>`.
- ElectronConfiguration and EmbeddedMath top-level constructs via aci:.
- `parse-cml` CLI subcommand.

## [0.2.0] - 2026-07-14

### Added
- Layout module (MoleculeWalker / GraphBuilder / ResultExtractor)
  using elkrb for 2D structural SVG.
- StructuralSvg formatter with bond-kind renderer registry.
- Ring closures (SMILES-style): `C1-C-C-C-C-C1` is cyclohexane.

## [0.1.0] - 2026-07-10

### Added
- Initial gem scaffold: autoload tree, version, errors.
- Core model: `Formula`, `Atom`, `Molecule`, `Group`, `Bond`,
  `Reaction`, `ElectronConfiguration`, `EmbeddedMath`, `Text`.
- Parslet parser and transform for v1 constructs.
- Formatters: MathML, Text (round-trip), HTML, LaTeX, SVG.
- Thor-based CLI: `convert`, `roundtrip`, `lint`, `parse-cml`,
  `version`.
- Comprehensive RSpec suite with round-trip conformance.

[Unreleased]: https://github.com/asciichem/asciichem-ruby/commits/main
[0.6.0]: https://github.com/asciichem/asciichem-ruby/compare/v0.5.1...v0.6.0
[0.5.1]: https://github.com/asciichem/asciichem-ruby/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/asciichem/asciichem-ruby/compare/v0.4.1...v0.5.0
[0.4.1]: https://github.com/asciichem/asciichem-ruby/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/asciichem/asciichem-ruby/compare/v0.3.4...v0.4.0
[0.3.4]: https://github.com/asciichem/asciichem-ruby/compare/v0.3.3...v0.3.4
[0.3.3]: https://github.com/asciichem/asciichem-ruby/compare/v0.3.2...v0.3.3
[0.3.2]: https://github.com/asciichem/asciichem-ruby/compare/v0.3.1...v0.3.2
[0.3.1]: https://github.com/asciichem/asciichem-ruby/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/asciichem/asciichem-ruby/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/asciichem/asciichem-ruby/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/asciichem/asciichem-ruby/releases/tag/v0.1.0
