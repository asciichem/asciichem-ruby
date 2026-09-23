# Parsing benchmarks

Shared workload (identical inputs in every implementation) so numbers
are comparable across engines:

```ruby
WORKLOAD = ["H_2O", "Ca^2+", "SO_4^2-", "(R)-CH_3CH(OH)COOH",
            "2H_2 + O_2 -> 2H_2O", "N_2 + 3H_2 <=>[Fe][400C] 2NH_3",
            "C1-C-C-C-C-C1", "CH_3-CH_2-OH",
            "^14C @name(\"carbon-14\") @cas(\"14104-86-4\")",
            "A ->[heat] B ->[cool] C"]
```

| Engine | Batch (10 inputs) | Per input | Notes |
|---|---|---|---|
| Ruby (parslet), 3.4.8 arm64 | 29.1 ms | ~2.9 ms | `bundle exec ruby benchmarks/engines.rb` |
| Ruby + parse+text | 35.3 ms | ~3.5 ms | round-trip adds the formatter |
| Ruby (parsanol compat, :ruby), 1.3.13 | 19.9 ms | ~2.0 ms | `benchmarks/parsanol_recheck.rb`, same session as the 11.8 ms parslet baseline below |
| TypeScript (peggy), Node 24 | 0.19 ms | ~19 µs | `npm run bench` (asciichem-ts) |
| Python (RD), 3.10 | 3.94 ms | ~394 µs | `python benchmarks/engines.py` (asciichem-py) |

The peggy engine is ~15x faster than parslet and ~20x faster than the
Python recursive-descent parser on this workload — the grammar-port
TS implementation did not trade away speed. Same machine (arm64),
single-run medians; treat as order-of-magnitude comparison.

## Parsanol investigation (2026-09-14)

[Parsanol](https://github.com/parsanol/parsanol-ruby) (Ribose's
parslet-alternative PEG library with a Rust native core) was evaluated
as a drop-in speedup for the reference grammar:

1. **Parslet-compat shim** (zero code change — re-parent the grammar
   onto `Parsanol::Parslet::Parser`): the identical grammar runs
   unchanged (10/10 workload inputs), but measures **~6x slower**
   than parslet (12.2 s vs 2.05 s per 300x10 parses, Ruby 3.4.8,
   arm64). The shim is a compatibility layer, not the fast path.
2. **Native Parsanol DSL** (subset micro-benchmark): constructs run,
   but boundary semantics differ from parslet on greedy-regex +
   `maybe`/`repeat` interaction (`SO_4^2-` parses under parslet,
   fails under Parsanol native). A full port would need per-rule
   revalidation against the whole corpus with no measured win to
   justify it yet.

**Verdict: not adopted yet.** Two corrections to the spike (tracked
upstream in parsanol-ruby#25):

1. The native-DSL micro-benchmark ran in Parsanol's default `:ruby`
   mode — the Rust core (`:native`) was never engaged, so the native
   path is unmeasured, not disproven.
2. The `SO_4^2-` failure is a candidate upstream bug (`repeat` of a
   `maybe`-prefixed sequence fails at end-of-input; minimal repro in
   the issue).

Revisit trigger unchanged: engage the native backend for full
grammars, fix the repetition-termination bug, and beat parslet on
this workload — then re-run the corpus against the port.

### Re-check (2026-09-14, parsanol 1.3.13)

The upstream "native by default" + RepetitionTag work landed, so the
revisit trigger was tested (`benchmarks/parsanol_recheck.rb`):

1. **The repetition-termination bug is fixed.** `SO_4^2-` parses and
   round-trips, and the unmodified grammar passes the entire shared
   corpus through the `Parsanol::Parslet` compat layer —
   **221/221** parse/reject/round-trip cases identical to parslet.
   One divergence surfaced on our side and is fixed in the gem:
   parsanol's transform delivers cascade tail segments as scalar
   hashes, and `CascadeBuilder#canonicalise_hash` used `Array(hash)`
   (which enumerates a Hash instead of wrapping it) — now wraps
   explicitly, engine-agnostic.
2. **Perf (compat, :ruby forced):** 19.9 ms vs 11.8 ms per 10-input
   pass in the same session — **~1.7x slower than parslet** (down
   from ~6x in the first investigation). Correct but not a win.
3. **Native still cannot serialize full parslet grammars** — two
   upstream bugs (reported in parsanol-ruby#25):
   `native.rb` never loads `native/dynamic` (NameError silently
   falls back to :ruby), and `Dynamic.register` never increments
   `@next_id`, so the second lazily-bound rule panics the Rust core
   with "callback ID 1000000 is already registered".

**Verdict: still not adopted — but one small upstream fix away from
a meaningful re-measure.** Corpus correctness is already there; the
native path is the whole point and remains unmeasurable until
serialization survives a multi-rule grammar.

### Re-check 3 (2026-09-15, parsanol 1.3.15)

The mode-routing/VM rework landed; native now engages for the full
grammar (`PARSANOL_MODE=native` in `benchmarks/parsanol_recheck.rb`,
fork-per-case gate so Rust aborts are reported, not fatal):

- **219/221 corpus cases green under native** — every accept case
  except the two embedded-math inputs, and all 51 rejects clean
- **3.2x faster than parslet** on the workload (4.28 ms vs 13.64 ms
  per 10-input pass, same session, ±3.0%)
- The two failures are the embedded-math grammar paths hitting
  `serialize_dynamic` — the still-unfixed `@next_id` collision from
  the re-check above (manifests as the Rust panic or a Ruby-side
  `NoMethodError` on the native error path). Upstream thread:
  parsanol-ruby#25 (third comment).
- Separately noted upstream: `H2` / `_2O` are accepted under native
  but rejected under parslet (optimizer Str/Re run-merging semantics;
  no corpus case covers these spellings today).

### Re-check 5 (2026-09-15, parsanol 1.3.17)

The ffi-gem cdylib tier (Rust engine on every runtime) changes
nothing for us: gate still **221/221**, 4.40 ms/i on the recheck
workload. The opt-in engine shipped in asciichem 0.29.0 is
unaffected; `@next_id` remains unfixed upstream but no longer fires
on corpus inputs. The re-check-3 verdict below is superseded — the
engine IS switchable and shipped (TODO.impl 64).

**Verdict: superseded — the engine IS switchable and shipped**
(asciichem 0.29.0, TODO.impl 64).

### Re-check 6 (2026-09-16, parsanol 1.3.18)

Gate still **221/221** through the shipped engine, but the "one
decode path" rework **regressed compat-layer throughput ~60%** for
this grammar: 7.2 ms/batch (138 i/s) vs 4.3-4.6 ms on 1.3.15/16,
with the parslet control stable across sessions (11-14 ms
throughout). The `H2`/`_2O` acceptance divergence also persists.
Reported upstream (parsanol-ruby#25, fourth comment). We stay on
the shipped engine; users pinning parsanol for speed should prefer
1.3.16/1.3.17 until the regression is addressed.

### Re-check 7 (2026-09-16, parsanol 1.3.20)

Three upstream issues closed since 1.3.18:

- **#38** (`Dynamic.register` `@next_id` collision panicking the
  Rust core) — fixed; no panic during full-corpus run.
- **#37** ("one decode path" throughput regression) — fixed as a
  side effect of the optimizer acceptance fix in #39; throughput on
  this grammar is back to and ahead of 1.3.15/16 levels.
- **#39** (optimizer Str/Re run-merging changed sequence-boundary
  acceptance) — root-caused to Re-run regex-source concatenation
  (proven unsafe: `"a|"+"b"` → `"a|b"` accepts `"a"`); Re runs now
  stay unmerged, Str-run merging stays. Spec-level decision
  recorded: the optimizer may never alter acceptance.

Validation against 1.3.20:

- Gate **221/221** through the shipped `ParsanolEngine` (fork-per-case,
  no Rust aborts).
- Head-to-head vs parslet, same Ruby process (3 runs, ±3-15%):
  parsanol **2.6x faster** (4.65–5.19 ms/batch vs 12.18–13.65 ms for
  parslet). Up from the 1.7x under 1.3.18 — the #37 regression is
  gone.
- Direct `H2` / `_2O` / `Ca2+` / `H22` / `O2` probe across both
  parslet and parsanol (native and ruby backends) shows **identical
  parse outcomes**. The earlier "divergence" framing in re-checks
  3-6 was a misreading: AsciiChem's `hydrogen_atom` grammar rule
  intentionally permits bare-digit subscripts after `H` ("lets users
  write `H2O` instead of `H_2O`" — grammar_rules.rb:228-231) and
  `isotope_marker` accepts both `^digits` and `_digits`, so `_2O`
  parses as the isotope of `O` and round-trips as `^2O`. The
  parsanol optimizer bug in #39 was real and is fixed, but the
  AsciiChem repro was a misleading example — both engines agree on
  these inputs because they share the same grammar rules.

**Verdict: shipped engine fully validated.** 2.6x speedup, 100%
corpus gate, all four reported upstream issues now resolved or
non-blocking (#36 bare repeated sibling captures remains open but
is worked around in `ParsanolEngine` via single `.as(...)` capture
wrapping).


### Re-check 8 (2026-09-17, parsanol 1.3.27)

All four upstream issues we filed are now closed (#36-#39; seven
releases since 1.3.20). Validation:

- Gate **221/221** through the shipped `ParsanolEngine`.
- **#36 verified fixed at the source**: the bare-repeated-sibling
  repro (`A->B->C`) now returns parslet's array-of-segment-hashes —
  every match preserved. Our `split_merged_formula` seam in
  `ParsanolEngine` is therefore a compatibility no-op on current
  parsanol (it still normalizes the merged-hash shape for older
  parsanol lines, which the opt-in floor allows).
- **Perf: ratio-only this time.** The machine ran at load ~45
  during measurement (parallel spec suites in other sessions), so
  absolute numbers are meaningless — the parslet control itself
  measured 15-20x slower than its quiet-machine baseline.
  Same-process ratio: parsanol **~2.1x parslet** (8.3 vs 3.8 i/s,
  and 8.8 vs 4.5 on the repeat), consistent with the 2.6x
  quiet-machine figure from re-check 7.

### Re-check 9 (2026-09-22, parsanol 1.3.49)

Twenty-one releases since re-check 8, all perf-focused upstream
(#59 roadmap: first-set BYTE_DISPATCH 1.3.29, VM memoisation
1.3.35, VM phase-2 wiring 1.3.33, native dynamic bridge fixes
1.3.40-1.3.41, `Parsanol::IncrementalSession` 1.3.42). Validation:

- Gate **221/221** through the shipped `ParsanolEngine` (run on
  1.3.48/1.3.49 within the same day — the line is moving fast).
- **Perf: ratio-only again.** Load was 34-77 during measurement
  (parslet control itself ran 8-12 i/s vs its quiet ~75), so
  absolute numbers are excluded. Same-process ratio across three
  runs: parsanol **1.7-3.2x parslet** (37.7/11.7, 19.0/11.1,
  25.5/8.4), centring ~2.5-3x — consistent with the quiet-machine
  2.6x from re-check 7; under contention the native parse path
  degrades less than pure-Ruby parslet.
- Upstream's incremental (`Parsanol::IncrementalSession`) and VM
  memoisation work benefits the compat layer automatically; no
  asciichem-side change needed or made.

## Leptris note (2026-09-22, 1.9.221)

Leptris is moxml's PREFERRED_ADAPTER: when installed above its
binding floor, lutaml-model's XML layer (our CML wire path) runs on
it. The version is fully transitive — lutaml-model constrains
`~> 1.9.178`; asciichem pins nothing. The line moves fast
(1.9.178 floor -> 1.9.222 within days).

- **Compatibility:** full suite **1985/0** at 1.9.221.1, including
  every CML round-trip and three-way wire spec. 1.9.222's namespace
  fix (`xml:space` in the interleaved lane, reported upstream by
  Canon) does not affect our documents; no action.
- **Perf on our CML workload:** leptris is ~15-25% behind nokogiri
  (round-trip 12.7 vs 15.0 i/s; emit 30.6 vs 39.8 i/s; load-noisy
  ±20%). The workload is dominated by lutaml-model's Ruby-side
  model building, not the adapter — leptris's speed gains target
  its native parse lanes (HTML/XQuery per its release notes).
  Measurement caveat: forcing an adapter for A/B runs requires
  stubbing `leptris_preferred_available?` — lutaml's
  `detect_xml_adapter` calls `runtime_default_adapter`, which
  ignores `default_adapter=`.

### Re-check 10 (2026-09-23, parsanol 1.3.52)

Three releases since re-check 9 — notable upstream: 1.3.50 pins
cross-engine consume-all/recursion semantics (closing the five
PR-#22 divergence skips), 1.3.51 consolidates on a single Symbol
tag form. Validation:

- Gate **221/221** through the shipped `ParsanolEngine` — every
  accept/reject/round-trip case identical to parslet, including the
  optimizer-acceptance semantics pinned upstream in 1.3.50.
- The compat surface our engine rides (`Parsanol::Parslet::Parser`)
  now resolves through `Parsanol::Parser` — renamed/absorbed
  upstream during the 1.3.3x-4x line; our subclassing works
  unchanged (the gate is the proof) and needs no engine-side change.
- **Perf: ratio-only** (machine at load ~175 during measurement —
  the parslet control measured 7-9 i/s against its quiet ~75):
  parsanol **2.6-3.2x parslet** across two same-process runs
  (22.8/7.2, 24.3/9.4), consistent with re-checks 8/9.
- The unpublished v1.0.1 draft noted in re-check 9 is still
  untagged/unpublished; nothing to validate there yet.
