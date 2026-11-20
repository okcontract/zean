# Validation

Use Zig **0.17.1** and Lean **4.35.0**. The portable suite uses only repository
inputs and the pinned public toolchains.

```sh
zig build
zig build test
zig build fmt-check
zig build lean
zig build check -Doptimize=ReleaseFast
```

`test` checks native AIR admission and rejection controls, source declaration
ownership, specializations, direct-call identities, pointer/record geometry,
undefined-byte transport, capture provenance, archive safety, process cleanup,
and the tutorial source/model identities. Inputs and explicit mutations live in
`test/native/cases/`; independently recorded expected values live in
`test/native/cases/golden.zig`. Synthetic fixtures are data, not native captures.

The process controls cover literal argv, file-backed logs, ordinary failures,
deadlines, interruption, descendant cleanup, and unavailable worker capacity.
Deadlines require concurrency; they cannot fall back to an inline sleep on a
one- or two-CPU machine.

`lean` checks every included `Contract` and `Compiler` module plus declaration
encoding controls. `check` also builds the CLI, checks formatting, runs native
regressions, compiles newly emitted controls across all nine AIR profiles, and
requires the deliberately false tutorial proofs to fail for their expected
obligations. A certificate mutation must fail in the independent decoder, not
through an unrelated syntax or import error.

The workflow in [`.github/workflows/check.yml`](../.github/workflows/check.yml)
runs native Debug regressions and the ReleaseFast portable gate on Linux.
Complete Lean library builds use two workers. Certificate and fresh-client
replay processes run sequentially with one explicit Lean worker each. Keep
aggregate verification memory within 8 GiB and avoid concurrent gates rebuilding
the same inputs.

## Example checks

```sh
zig build counter
zig build buffer
zig build copy
zig build calls
zig build stdlib-replace
zig build ziglings
zig build wp-proofs
```

The counter checks both byte versions and the universal `u32` contract. The
buffer checks allocation bounds, logical subviews, preservation of surrounding
memory, and the off-by-one witnesses. The copy client checks initialization,
bounds, non-overlap, helper contracts, and effects retained after faults. The
call and standard-library clients check separately verified helper contracts
and correspondence to the supplied captured program data. Ziglings also runs
the two pinned upstream corrections natively.

## Fresh capture release gate

An ordinary compiler installation cannot generate AIR records. Build a matching
instrumented compiler with [the toolchain guide](toolchain.md), then supply its
completed report and a new output directory:

```sh
zig build release-check -Doptimize=ReleaseFast \
  -Dtoolchain-report=/path/to/instrumented-build/report.json \
  -Drelease-output=/tmp/new-release-evidence
```

This gate first runs the portable checks, then fresh memory and validity audits,
tutorial recaptures, independent AIR correspondence checks, positive proof
replay, and expected negative clients. It also checks the held-out ASCII call
rejections and the fixed-length slice admission probe. Stages run sequentially
and preserve their input identities and actual process outcomes.

The last stage captures fresh AIR for `publish` and `readEntry`. Lean checks
the two functions against the dispatch-table model, then repeats the comparison
with six deliberate changes to the AIR. All six must break the match. The
capture and proof reports are under `atomic-publication/capture` and
`atomic-publication/proof` in the release output directory.

The retained model checks, synthetic capture fixtures, fresh native capture,
object comparisons, and whole-compiler verification are distinct claims. See
[verification evidence](evidence.md) and [architecture](architecture.md).

## Measuring proof cost

```sh
zig build benchmark -- --output .codex-tmp/proof-cost
```

This measures fresh main-file elaboration with warm imported modules. Its report
records proof-file identities, elapsed time, peak waited-child memory, worker
limits, and cache scope. It does not measure toolchain construction or native
compilation. See [the measurement guide](verification.md#measuring-proof-cost).
