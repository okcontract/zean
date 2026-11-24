# Verify a call chain

`update` calls `replace`, which calls `inside`. The two `noinline`
helpers survive as direct calls in the captured AIR. [Zig source](calls.zig)

```sh
zig build calls
```

The target uses the retained call table to check native cases, Lean
contracts, and a false bounds proof.

The caller supplies a valid heap, a writable word view, an index, and
a value. Every finite observation is safe. An in-range index writes one
word and returns `true`. Rejection returns `false` and preserves the heap.
Modeled exhaustion also preserves caller memory. All outcomes preserve
heap validity, write access, and memory outside the view.

`inside_exact` proves the comparison. `replace_checked` uses its summary
to justify the guarded store. `update_checked` uses the store contract
without unfolding either helper. `update_terminates` separately checks
structural termination of the finite call table, including failures.
[Proofs](../../lean/Compiler/Tutorial/Calls/Proofs.lean)

## Recapture and replay

```sh
zig build calls-regenerate -- \
  --toolchain /path/to/toolchain/report.json \
  --output /tmp/calls-replay \
  --check
```

Replay compares the complete closure with the retained definitions and
checks the proofs on fresh models. For an intentional source change, omit
`--check`, review the generated candidate, and rerun after updating the
retained module. [Toolchain setup](../../docs/toolchain.md) ·
[Other call profiles](../../docs/architecture.md#supported-routes)
