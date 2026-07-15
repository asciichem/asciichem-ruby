# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

The reference implementation of **AsciiChem** — an ASCII syntax for
chemistry (atoms, molecules, bonds, reactions, electron
configurations, embedded math). Parses text into a semantic model and
renders the model to MathML, Text, HTML, LaTeX, SVG, and CML.

Sister repo: `../asciichem.github.io` is the specification site. When
a spec page describes syntax, the gem must implement it; when the gem
adds a feature, a spec page must document it. The site's
`TODO.impl/` directory tracks cross-repo work; this repo's
`TODO.gem/` directory tracks gem-side work.

## Why this exists (the semantic fix)

AsciiMath is insufficient for chemistry: prefix superscripts/subscripts
have no atom to bind to (AsciiMath forces a phantom `{}` carrier),
and there's no native syntax for stoichiometric coefficients, reaction
arrows, conditions, spectator ions, electron configurations, term
symbols, or bonds. AsciiChem closes these gaps. The defining fix
lives at the parser/model boundary: `^14C` parses as
`Atom(element: "C", isotope: "14")` — the isotope binds to the atom,
not to a phantom empty element.

## Commands

```bash
bundle install                          # install dependencies (chemicalml 0.1.0 from rubygems)
bundle exec rake spec                   # run the full spec suite
bundle exec rspec spec/asciichem/cml/   # run specs in a directory
bundle exec rspec -e "round-trips"      # run specs matching a name
bundle exec rubocop                     # lint
bundle exec rake build                  # build the gem into pkg/
bundle exec ./exe/asciichem convert -i "H_2O" -t mathml  # smoke-test the CLI
```

The default `rake` task is `:spec`. RSpec is configured for
randomised order, profile of the 10 slowest examples, and
`spec/examples.txt` persistence. `config.warnings = true` — Ruby
warnings fail the suite.

## High-level architecture

```
text ─► Grammar (parslet) ─► Transform ─► AsciiChem::Model ─► Formatter (visitor)
                                              │
                                              ▼
                                    ModelAdapter (bidirectional)
                                              │
                                              ▼
                            Chemicalml::Model (canonical, in chemicalml gem)
                                              │
                                              ▼
                            Chemicalml::Cml (CML wire, in chemicalml gem)
```

### Five layers, MECE

1. **Grammar** (`lib/asciichem/grammar.rb`) — a Parslet parser.
   Leaf rules return strings; `.as(:name)` is applied at the
   combination site so the parse tree is a flat hash of named strings
   wherever practical. The prefix-isotope binding (`^14C`) is enforced
   *structurally*: `prefixed_atom` consumes `^digits element` as a
   unit; a bare `^digits` with no following element is rejected.

2. **Transform** (`lib/asciichem/transform.rb`) — a Parslet transform
   that converts the flat parse tree into a tree of `Model::*`
   instances. Minimal logic; the grammar encodes semantics, not the
   transform. Builder classes (`AtomBuilder`, `ReactionBuilder`,
   `CascadeBuilder`) keep constructor-call mapping readable.
   `TextNormaliser.strip_quotes` removes the surrounding `"..."` from
   quoted-text matches so the model never carries the delimiters; the
   Text formatter re-adds them on output.

3. **Model** (`lib/asciichem/model/`) — the semantic hub. Every
   formatter consumes the same tree. Classes: `Formula`, `Atom`,
   `Molecule`, `Group`, `Bond`, `Reaction`, `ReactionCascade`,
   `ElectronConfiguration`, `EmbeddedMath`, `Text`. All inherit from
   `Model::Node`, which provides structural equality (via
   `value_attributes`), visitor dispatch (`accept`), and the
   `to_<format>` shortcuts.

   **Text syntax.** Free-form text uses `"..."` delimiters (matching
   AsciiMath). Unquoted prose that isn't chemistry raises
   `ParseError`; this is intentional — silently swallowing arbitrary
   content as Text was a bug magnet. Embedded math uses backticks
   (`` `...` ``) and is handled by a separate grammar rule.

4. **Formatter** (`lib/asciichem/formatter/`) — one visitor per output
   format. Each subclass of `Formatter::Base` implements one
   `visit_<class>` method per `Model::*` class. Missing visits raise
   `NotImplementedError` so gaps surface at first use, not silently.
   Reachable via `Formatter[:name]` (triggers autoload).

5. **ModelAdapter** (`lib/asciichem/model_adapter/`) — bridges
   `AsciiChem::Model` and the canonical `Chemicalml::Model` (which
   lives in the chemicalml gem). The adapter is bidirectional and
   pure; no I/O. Composed with `Chemicalml::Cml::Translator` it
   forms the AsciiChem ↔ CML pipeline.

### Linter (opt-in)

`lib/asciichem/linter/` is a separate pass that walks the model and
reports chemistry errors. Checks self-register via
`Linter::Base.register(:name)` inside their class body; the
`Linter` module eagerly triggers every autoload at load time so
registration runs before any API query.

Built-in checks:

- `BalanceCheck` — stoichiometric balance of reactions.
- `BracketBalanceCheck` — group bracket consistency.
- `ElementValidationCheck` — warns on element symbols not in the
  periodic table (catches typos like `Hx`, `Cy`).
- `IsotopeSanityCheck` — isotope mass ≥ atomic number.
- `UnclosedRingCheck` — errors on ring closure digits with no
  matching partner (`C1-C-C` is unmatched).
- `ValenceCheck` — atom bond order + charge ≤ max valence.

All element data (symbol, atomic number, max valence) is sourced
from `AsciiChem::PeriodicTable` — the single source of truth.
Adding a new field (covalent radius, common oxidation states) is
one column on `Element` plus populating it; the linter picks it up
automatically.

### Ring closures (SMILES-style)

Atoms can carry a digit suffix that opens or closes a ring:
`C1-C-C-C-C-C1` is cyclohexane. The `Atom#ring_closures` field
holds the digit string. `AsciiChem::RingBonds` is the single source
of truth for the "find ring bond pairs" algorithm — Layout,
ModelAdapter, and the UnclosedRingCheck linter all consume it.
Multiple closures on one atom (`C12-C-C1-C2`) and fused rings are
supported.

### Layout (2D structural SVG)

`lib/asciichem/layout.rb` converts a `Model::Molecule` into an elkrb
graph, runs the layout algorithm, and returns positioned atoms + bonds.
The `Formatter::StructuralSvg` visitor consumes the result. For
molecules without bonds it falls back to the linear SVG formatter.

Three MECE concerns inside Layout:

- `MoleculeWalker` — walks the AsciiChem tree, assigns stable IDs,
  produces a neutral atom+bond list. Pure; no elkrb dependency.
- `GraphBuilder` — converts the walker's neutral list into an
  elkrb `Graph::Graph` with proper nodes and edges.
- `ResultExtractor` — maps elkrb's laid-out positions back onto the
  walker's neutral list, producing a `Layout::Result`.

Default algorithm is `layered` (Sugiyama-style hierarchical) for
deterministic output across runs — essential for visual regression.
`force` is available but may produce different output between runs.

The `StructuralSvg` formatter uses a registry of bond-kind strategies
(Procs). Adding a new bond style is one Proc + one registry entry;
no edits to existing renderers.

## Extension points (OCP)

The system is open for extension in three dimensions; each dimension
requires edits in exactly one place.

- **New construct** — add a model class under `lib/asciichem/model/`,
  autoload it from `lib/asciichem/model.rb`, add grammar productions
  to `grammar.rb`, a transform rule in `transform.rb`, and a
  `visit_<class>` method on each formatter.
- **New output format** — create `lib/asciichem/formatter/<name>.rb`
  subclassing `Formatter::Base`, implement one `visit_<class>` per
  model class, and add the autoload to `lib/asciichem/formatter.rb`.
  Optionally add `to_<name>` to `Model::Node`. The `Formatter[:name]`
  lookup camelises snake_case names, so `:structural_svg` resolves
  to `StructuralSvg`.
- **New arrow / bond / bracket kind** — each enum
  (`Reaction::ARROWS`, `Bond::KINDS`, `Group#bracket`) is a constant
  hash. Adding a kind is a single entry; formatters read from the hash.
  For SVG rendering, also add a strategy Proc to
  `StructuralSvg::BondRenderer::RENDERERS`.
- **New linter check** — subclass `Linter::Base`, call `register(:name)`
  in the class body, implement `run(formula)`. The check self-registers
  at file-load time; the `Linter` module eagerly triggers every
  autoload so registration runs before any API query.
- **New model class** — add the class under `lib/asciichem/model/`,
  autoload from `lib/asciichem/model.rb`. Override `diagnostic_label`
  if the default (snake-case → space-separated capitalized words)
  isn't suitable. No edits to `Linter::Diagnostic` — it reads
  `node.diagnostic_label` polymorphically.

## CML and the canonical model

`AsciiChem::Cml` provides bidirectional CML XML conversion via the
chemicalml gem. The pipeline is:

```
AsciiChem::Model ↔ AsciiChem::ModelAdapter ↔ Chemicalml::Model
                                                       ↑
                                                       │
                                            Chemicalml::Cml::Translator
                                                       │
                                                       ▼
                                            Chemicalml::Cml::* (wire)
                                                       │
                                                       ▼
                                                       XML
                                                       │
                                            AsciiChem::Cml::Extensions
                                            (aci: namespace side-channel)
```

- `formula.to_cml` delegates to `AsciiChem::Cml.from_asciichem`.
- `AsciiChem::Cml.parse(xml)` delegates to
  `AsciiChem::Cml::Translator.to_asciichem`.
- `chemicalml` requires `Chemicalml::Cml::Schema3.ensure_registered!`
  before first wire-class use. `Cml::Translator` calls it lazily.

### aci: extension namespace

CML's standard wire format doesn't cover oxidation state, Lewis
markers, electron configuration, embedded math, free-form text, or
group structure. AsciiChem carries these through XML round-trip via
an `aci:` (AsciiChem extension) namespace on the CML root. Three
channels, one per scope:

- **Atom attributes** (per-atom fields): `aci:<wire_name>` on
  `<atom>` elements. Registry: `AsciiChem::Cml::Extensions::FIELDS`
  (covers oxidation_state, lone_pairs, radical_electrons).
- **Top-level elements** (standalone constructs):
  `<aci:<element_name> position="N">...</aci:...>` children of
  `<cml>`. Registry: `Extensions::TOP_LEVEL_HANDLERS` (covers
  ElectronConfiguration, EmbeddedMath, Text). Position preserves
  node ordering in the formula.
- **Molecule-level elements** (structural concepts):
  `<aci:group multiplicity="N" bracket="X" atomRefs="..."/>` children
  of `<molecule>`. Managed by `AsciiChem::Cml::GroupExtensions`
  (preserves AsciiChem Group nodes through the canonical-model
  flattening). Bracket kinds mapped via frozen
  `BRACKET_TO_WIRE` hash.

Adding a new extension is one entry in the appropriate frozen
registry. No other code changes. The `xmlns:aci` declaration appears
only when at least one extension is present; plain atoms/molecules
produce clean CML.

The `ModelAdapter::ToCanonical::MoleculeWalker` records group
membership during the canonical walk via a `GroupRecord` struct,
exposed through `Translation#groups`. `IdRegistry::PREFIXES`
includes `:group => "g"` so group IDs (`g1`, `g2`, ...) don't
collide with atom/bond/molecule IDs.

**Known limitations** (each guarded by a spec):
- 3D coordinates, spectroscopy, polymer notation — out of scope for v0.2.

See `TODO.gem/03-canonical-model-gaps.md` (all five canonical-model
gaps now closed) and `TODO.gem/09-group-preservation.md` (Group
preservation design).

## Critical constraints (project-specific)

The global `~/.claude/CLAUDE.md` is authoritative. Highlights that
apply most directly here:

- **Never use `require_relative`** for internal library code, and
  never use path-based `require` for files inside `lib/asciichem/`.
  Use Ruby `autoload`, declared in the immediate parent namespace's
  file (e.g. `lib/asciichem/model.rb` autoloads `Model::Atom`).
- **Never hand-roll serialization.** The model is in-memory only.
  CML wire (de)serialization goes through `lutaml-model` in the
  chemicalml gem. AsciiChem itself never writes a `to_h` / `from_h`
  / `to_xml` / `from_xml` on a model class.
- **No `double()` in specs.** Use real `Model::*` instances or
  lightweight `Struct`s.
- **No `send` to private methods, no `instance_variable_set` /
  `instance_variable_get`, no `respond_to?` type checks.** Visitor
  dispatch uses `public_send` against public `visit_*` methods.
- **Never commit to `main`, never push tags, never push to `main`.**
  Every change goes through a PR.
- **Never add AI attribution** to commit messages, PR descriptions,
  code comments, or changelog entries.

## Specs and conformance

- **Round-trip conformance** is the contract: `AsciiChem.parse(s).to_text == s`
  for any canonical `s`. The Text formatter is the canonicaliser.
- **Three-way round-trip** for CML: `parse(s).to_cml` →
  `Cml.parse(...)` → `.to_text` equals `s`. See
  `spec/asciichem/cml/cml_spec.rb` and the comprehensive case list
  in `spec/integration/edge_cases_spec.rb`.
- **Corpus fuzzing** at `spec/fuzz/corpus/` — 15 files exercising
  edge cases. Every line must either parse or raise
  `AsciiChem::ParseError` cleanly (no raw exceptions).
- **Edge cases** in `spec/integration/edge_cases_spec.rb` — 60+
  cases covering parser robustness (malformed inputs raise
  ParseError cleanly), parser acceptance (every documented
  construct), text and CML round-trip conformance, deterministic
  output across runs, formatter registry, linter coverage, and
  periodic-table coverage.
- **Known limitations are spec'd.** Don't silently drop constructs on
  round-trip; write a spec that documents the loss and link it to a
  `TODO.gem/` item that will close the gap.

## Performance

Manual benchmarks at `benchmarks/benchmark.rb`. Run with
`bundle exec ruby benchmarks/benchmark.rb`. Covers parse, text
round-trip, MathML output, and CML round-trip. CI does not run
benchmarks; they are a development-time regression check.

## Releasing

See `RELEASING.md` for the full release runbook. Short version:
bump `lib/asciichem/version.rb`, update `CHANGELOG.md`, open a PR,
merge, then (maintainer only) tag and `gem push`. Never push tags
yourself.
