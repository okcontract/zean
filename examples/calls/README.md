# Verify a call chain

This example keeps three Zig functions separate: `update` calls `replace`,
which calls `inside`. The two helpers are declared `noinline`. Translation
emits all three captured bodies and their direct calls.

```sh
zig build calls
```

The command runs native controls, checks the Lean contracts, and confirms that
an intentionally false bounds proof fails. The generated call-machine table is translated from a real instrumented Zig
0.17.1 capture.

## What is proved

For every valid caller heap, writable logical word view, representable index
and word value, every finite observation of the generated `update` is safe.
When execution finishes, its outcomes satisfy:

- An in-range index returns `true` and changes exactly that word.
- An out-of-range index returns `false` and preserves the heap.
- Modeled allocation exhaustion preserves caller memory.

`update_terminates` separately checks a structural termination certificate for
the complete finite closure, including ordinary failures.

All outcomes preserve heap validity, the writable capability and memory outside
the logical view. The contract excludes other faults. It permits allocation
exhaustion; it does not establish successful completion for every native stack.

The [proof file](../../lean/Compiler/Tutorial/Calls/Proofs.lean) follows the call
graph. `inside_exact` verifies the comparison. `insideContract` packages its
effect, and `inside_spec` registers it for `vcgen`. `replace_checked` uses that
contract to justify the guarded store. `update_checked` supplies
`replace_spec view index value` to `machine_vcgen`, reusing the callee result without
unfolding either helper implementation.

The buffer effect specification is shared with the
[single-function buffer tutorial](../buffer/README.md). The verifier itself
contains no names or instruction numbers from either example. Cleanup facts,
instruction rules and contract composition live in `Compiler.ZigAir`.

## Capture and replay

With an [instrumented toolchain](../../docs/toolchain.md), run:

```sh
zig build calls-regenerate -- \
  --toolchain /path/to/instrumented-build/report.json \
  --output /tmp/calls-replay \
  --check
```

This captures the root and reached helpers, compares the complete generated
closure with the retained definitions, replays the handwritten proofs against
the fresh definitions, and checks the false proof. Captures and evidence stay
outside the checkout. Regenerate without `--check` when reviewing an intentional
source change, inspect the generated definitions, update the retained module,
and replay with `--check` afterwards.

For another program, use the `calls` profile for finite callers or `call-loops`
for callers with loop invariants. Those profiles require finite callees.
The `nested-calls` profile also supports looping callees through finite-observation
contracts; see the [call-machine guide](../../docs/call-machine.md).
All calls must be direct, acyclic and within the explicit captured source closure. Unsupported operations,
specializations and identities reject before publication. See the
[verification guide](../../docs/verification.md) for the generic interface and
the remaining source/compiler trust boundaries.
