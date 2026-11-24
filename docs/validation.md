# Validation

Use Zig **0.17.1** and Lean **4.35.0**. The portable checks use retained inputs
from this checkout.

```sh
zig build test
zig build fmt-check
zig build lean
zig build check -Doptimize=fast
```

`test` covers admission and rejection, source ownership, specializations,
call identities, memory layout, byte initialization, archive and process
handling, and tutorial source hashes. Find fixtures and explicit mutations
in `test/native/cases/` and independently recorded results in `golden.zig`.

`lean` checks all `Contract` and `Compiler` modules plus declaration encoding
controls. `check` also builds the CLI, runs native regressions and formatting
checks, compiles newly emitted Lean, and requires false tutorial proofs to
fail at their intended obligations.

CI runs the native debug suite and portable fast gate on Linux. Run Lean scopes
separately with two workers and keep aggregate verification within 8 GiB.
Certificate and fresh-client proof processes have one Lean worker each and
run serially. [CI workflow](../.github/workflows/check.yml) ·
[Focused Lean targets](architecture.md#lean-models)

## Fresh capture release gate

Build the matching instrumented compiler and use a new external output
directory. [Toolchain setup](toolchain.md)

```sh
zig build release-check -Doptimize=fast \
  -Dtoolchain-report=/path/to/instrumented-build/report.json \
  -Drelease-output=/tmp/new-release-evidence
```

The gate runs portable checks, fresh memory and validity audits, tutorial
recaptures and proof replays, and the recursive-call client. It also checks
ASCII call rejections and fixed-length slice admission. The final step
captures `publish` and `readEntry`, checks them against the dispatch-table
model, and requires six AIR mutations to fail correspondence. Find those
reports under `atomic-publication/capture` and `atomic-publication/proof`.
[Compatibility probes](../examples/compatibility/README.md) ·
[Publication proof](../examples/atomic_publication/README.md)

## Measuring proof cost

`zig build benchmark -- --output /tmp/proof-cost` times fresh proof
elaboration with warm imports. [Options and measurements](verification.md#measuring-proof-cost)
