# Performance benchmarks

Manual benchmarks for AsciiChem. CI does not run them; they exist to
surface regressions during development.

## Run

```bash
bundle exec ruby benchmarks/benchmark.rb
```

If `benchmark-ips` is installed (add to Gemfile dev group), the output
is iterations-per-second. Otherwise the script falls back to stdlib
`Benchmark` and reports wall-clock time per call.

## Suites

- **parse** — `AsciiChem.parse(source)` alone.
- **round-trip** — `parse + to_text`.
- **to_mathml** — `Formula#to_mathml` on a pre-parsed formula.

Each suite runs against a fixed set of inputs spanning every construct:
atoms, molecules, isotopes, charges, groups, reactions, equilibrium
with conditions, cascades, electron configs, and bonds.

## Baseline numbers

Captured on the maintainer's machine (Apple M1, Ruby 3.4). Update this
table when significant refactors land; investigate regressions of more
than 2x.

| Input | parse (ips) | round-trip (ips) | to_mathml (ips) |
|---|---|---|---|
| simple atom (H) | _tbd_ | _tbd_ | _tbd_ |
| simple molecule (H_2O) | _tbd_ | _tbd_ | _tbd_ |
| isotope (^14C) | _tbd_ | _tbd_ | _tbd_ |
| charged atom (Ca^2+) | _tbd_ | _tbd_ | _tbd_ |
| group (Ca(OH)_2) | _tbd_ | _tbd_ | _tbd_ |
| reaction (2H_2 + O_2 -> 2H_2O) | _tbd_ | _tbd_ | _tbd_ |
| equilibrium (Haber) | _tbd_ | _tbd_ | _tbd_ |
| cascade (A -> B -> C -> D) | _tbd_ | _tbd_ | _tbd_ |
| electron config | _tbd_ | _tbd_ | _tbd_ |
| bonds (H-O-H=O#H) | _tbd_ | _tbd_ | _tbd_ |

## When to investigate

- Any input that drops below 100 ips on parse.
- A regression of more than 2x in any cell.
- New grammar productions that fall off the table's curve.
