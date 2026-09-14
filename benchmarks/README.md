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
