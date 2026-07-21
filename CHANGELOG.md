# Changelog

All notable changes to AsciiChem are documented here.
This project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.18.0] - 2026-07-21

### Changed
- Beyond-formulas body validation: MechanismBuilder, SpectrumBuilder,
  and CalculationBuilder now validate each body line at parse time.
  Malformed entries (missing `:` separator) raise `ParseError` with
  the offending line number and content, instead of being silently
  dropped.

## [0.17.0] - 2026-07-21

### Added
- `Atom::Point3` value object (Struct with `x`, `y`, `z`, `to_a`,
  `magnitude`).
- `Atom#cartesian` and `Atom#fractional` accessors return Point3
  bundling the flat coordinate fields. Backwards compatible: flat
  accessors (`x2`/`y2`/`z2`, `x_fract`/`y_fract`/`z_fract`) remain.

## [0.16.0] - 2026-07-21

### Added
- `Node#to_structural_svg` shortcut — invokes
  `Formatter::StructuralSvg` for 2D diagram output. For Crystal
  nodes, projects fractional coordinates onto the ab-plane with a
  unit cell outline; for molecules with bonds, uses elkrb for
  graph layout (existing behaviour); falls back to linear Svg
  otherwise.
- `Formatter::StructuralSvg#visit_crystal` — renders a Crystal as
  a 2D projection of fractional coordinates with unit cell outline.

## [0.15.0] - 2026-07-21

### Changed
- Parser error messages now report `line N, col M` for multi-line
  inputs instead of `char N`. The caret pointer is positioned on
  the relevant line. Single-line inputs continue to use the
  existing char-position format.

## [0.14.0] - 2026-07-21

### Added
- `lint -f json` CLI option — emits diagnostics as a JSON array for
  tooling integration (CI, editors, downstream scripts). Each
  entry has `severity`, `message`, and `node` fields.

## [0.13.0] - 2026-07-21

### Added
- `Molecule#formula_weight` — sum of `atomic_mass × count` across
  all atoms (recurses through groups and nested molecules). Returns
  nil if any element lacks atomic mass data. Examples:
  `parse("H_2O").nodes.first.formula_weight` returns `18.015`;
  `parse("C_6H_12O_6")` returns `180.156`.
- `PeriodicTable.atomic_mass(symbol)` — IUPAC 2021 standard atomic
  weights for ~50 common elements. Single source of truth for
  atomic mass data.

### Changed
- `PeriodicTable::Element` struct gains `atomic_mass` field (nil
  when unpopulated).

## [0.12.0] - 2026-07-21

### Added
- `Molecule#hill_formula` — Hill-system canonical formula (C first,
  then H, then others alphabetically). Useful for indexing and
  display. `parse("C_2H_6O").nodes.first.hill_formula` returns
  `"C2H6O"`; `parse("H_2SO_4")` returns `"H2O4S"`.

### Changed
- `Linter.run` sorts diagnostics by severity (errors first) then by
  message for stable UX output. Also deduplicates identical
  (message, node) pairs from different checks.
- `AsciiChem::Parser` caches `Grammar` and `Transform` instances at
  the class level instead of allocating per parse. Benchmark: ~15%
  throughput improvement on repeated parses.

## [0.11.0] - 2026-07-21

### Added
- **Native CML wire for ZMatrix, Calculation, Mechanism, and
  reaction conditions.** Completes the native-wire migration arc
  for all beyond-formulas constructs:
  - ZMatrix emits as `<molecule>` with `<zMatrix>` child carrying
    the text form (structural length/angle/torsion children are a
    future enhancement).
  - Calculation emits as `<molecule>` with `<propertyList>` of
    `<property>` children, each with a `<scalar>` carrying value
    and units.
  - Mechanism emits as `<reaction>` with `<mechanism>` child.
    Currently uses the text form via title attribute; structural
    step-by-step representation is a future enhancement.
  - Reaction conditions (`<=>[Fe][400C]`) now emit as native
    `<conditionList>` with `<scalar>` children for above/below,
    replacing the `aci:conditionsAbove`/`aci:conditionsBelow`
    attributes used in v0.10.0 and earlier.

### Changed
- `ConditionsExtensions.inject`: now a no-op when native
  `<conditionList>` is present (defensive fallback only).
- `ModelAdapter::FromCanonical`: reads native `<conditionList>`
  via `conditions_from_canonical`.

## [0.10.0] - 2026-07-21

### Added
- **Native CML wire for Spectrum.** Spectrum nodes now emit as a
  `<molecule>` containing a native `<spectrum>` child (with `format`
  and `condition` attributes) plus a `<peakList>` of `<peak>`
  elements. Each peak carries `xValue`, `yValue`, `yMultiplicity`,
  and `title` (assignment) attributes per the CML Schema 3 spec.

### Changed
- `ModelAdapter::ToCanonical`: new `spectrum_to_canonical` mapper
  wraps Spectrum in a Molecule wire object with spectrum child.
- `ModelAdapter::FromCanonical`: detects molecule-with-spectrum and
  rebuilds as Spectrum node.
- `Translator::NATIVELY_WIRED`: now includes Spectrum.

## [0.9.0] - 2026-07-21

### Added
- **Native CML wire for Crystal.** Crystal nodes now emit as a
  `<molecule>` containing a native `<crystal>` child (with `<scalar>`
  cells and `<symmetry spaceGroup=...>`) plus an `<atomArray>` with
  fractional coordinates. Other CML tools can now read AsciiChem
  crystal output directly without needing the aci: extension
  namespace. Round-trip preserves all fields. The legacy aci:
  text-carrier form is still accepted on parse for backwards
  compatibility.

### Changed
- `ModelAdapter::ToCanonical`: new `crystal_to_canonical` mapper
  wraps Crystal in a Molecule wire object.
- `ModelAdapter::FromCanonical`: detects molecule-with-crystal and
  rebuilds as Crystal node.
- `Extensions::TopLevel.collect`: accepts `skip_classes:` parameter
  to suppress the aci: text carrier for constructs with native wire.
- `Translator::NATIVELY_WIRED`: registry of construct classes that
  have been migrated to native wire (currently just Crystal).

## [0.8.0] - 2026-07-21

### Changed
- `chemicalml` dependency bumped from `~> 0.2.1` to `~> 0.3.0`.
  chemicalml 0.3.0 fixes the wire serialization gaps that blocked
  Phases 06-10, 15 (native CML wire for Crystal/Spectrum/ZMatrix/
  Mechanism/Calculation/conditions). Molecule wire now serializes
  `<crystal>`, `<spectrum>`, `<zMatrix>`, `<propertyList>` children;
  Reaction wire now serializes `<conditionList>`, `<spectatorList>`,
  `<mechanism>` children.

### Added
- `.github/workflows/release.yml` — manual-dispatch release workflow
  that pushes the gem to RubyGems. Triggered via `gh workflow run
  release.yml -f version=X.Y.Z` after the version-bump PR merges.
  Verifies the input version matches `lib/asciichem/version.rb`.

## [0.7.0] - 2026-07-21

### Added
- Implicit subscripts on Hydrogen: `H2` now parses as `H_2`, so
  users can write `H2O`, `CH4`, `NH3` without explicit underscores.
  Resolves the long-pending feature request without breaking
  SMILES-style ring closures on other elements (Hydrogen cannot
  form ring closures — only 1 bond — so bare digits after H are
  unambiguously subscripts).

### Changed
- Grammar: new `hydrogen_atom` rule placed before `plain_atom` in
  the unit dispatch. The `match('[a-z]').absent?` lookahead ensures
  `He`, `Ho`, etc. fall through to plain_atom unchanged.

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
[0.18.0]: https://github.com/asciichem/asciichem-ruby/compare/v0.17.0...v0.18.0
[0.17.0]: https://github.com/asciichem/asciichem-ruby/compare/v0.16.0...v0.17.0
[0.16.0]: https://github.com/asciichem/asciichem-ruby/compare/v0.15.0...v0.16.0
[0.15.0]: https://github.com/asciichem/asciichem-ruby/compare/v0.14.0...v0.15.0
[0.14.0]: https://github.com/asciichem/asciichem-ruby/compare/v0.13.0...v0.14.0
[0.13.0]: https://github.com/asciichem/asciichem-ruby/compare/v0.12.0...v0.13.0
[0.12.0]: https://github.com/asciichem/asciichem-ruby/compare/v0.11.0...v0.12.0
[0.11.0]: https://github.com/asciichem/asciichem-ruby/compare/v0.10.0...v0.11.0
[0.10.0]: https://github.com/asciichem/asciichem-ruby/compare/v0.9.0...v0.10.0
[0.9.0]: https://github.com/asciichem/asciichem-ruby/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/asciichem/asciichem-ruby/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/asciichem/asciichem-ruby/compare/v0.6.0...v0.7.0
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
