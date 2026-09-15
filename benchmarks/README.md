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

**Verdict: one upstream one-liner from adoption evaluation.** With
`@next_id += 1` fixed, the entire corpus passes under native at
3x parslet speed — at that point the decision is whether to make the
engine switchable (opt-in, soft dependency) in the gem.


