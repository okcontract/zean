# Verify an unchanged Zig standard-library loop

This client verifies the captured `u32` specialization of Zig 0.17.1's
`std.mem.replaceScalar`. The original implementation loops over a mutable slice
and replaces each matching element. It is not copied into the translator or
rewritten to fit the proof. The small [Zig wrapper](replace.zig) makes the
specialization available for capture.

```sh
zig build stdlib-replace
```

This checks native results, the actual standard-library source hash, the Lean
contract, concrete execution controls and two intentionally false proof clients.
The retained model needs no instrumented compiler to check.

## Contract and proof

The [generated module](../../lean/Compiler/Components/Replace/Generated.lean)
contains only program data and capture provenance. The separate
[proof client](../../lean/Compiler/Components/Replace/Proofs.lean) supplies:

- A valid caller heap and a writable word view whose extent fits its allocation.
- Initialization of every word that the slice may read.
- A loop invariant relating the index to the slice length, retaining initialization
  and a frame for memory outside the view.

`air_vcgen` derives the obligations from the generated program. The reusable
slice, word and frame rules discharge them. Checked selectors locate bindings
and the loop label in program data; the verifier has no rule for this function's
name or instruction numbers.

For every execution prefix, the contract excludes invalid access, uninitialized
read, permission, arithmetic and malformed-program faults. Completed execution
preserves heap validity, initialized contents, writable extent and memory outside
the view. Modeled allocation exhaustion is permitted and has the same preservation
guarantees. The current universal contract does **not** prove termination or
the exact replacement list. Concrete positive controls check replacement results,
including neighboring words and an empty view.

[Negative controls](../../lean/Compiler/Components/Replace/Controls.lean) show
that a valid heap alone is insufficient: a missing initialized word faults,
readonly storage rejects a write, and an exaggerated slice exceeds physical
bounds. A write reached before a later fault remains observable. Unsafe cases
execute only in the model.

## Capture, certify and replay

Build an instrumented compiler using the [toolchain guide](../../docs/toolchain.md),
then use a new directory outside the checkout:

```sh
zig build stdlib-replace-regenerate -- \
  --toolchain /path/to/instrumented-build/report.json \
  --output /tmp/stdlib-replace-evidence \
  --check
```

The command captures the wrapper and dependency, selects the original
`mem.replaceScalar__func_0` body, checks its scoped source owner and concrete
type-parameter mapping, and translates it with the `loops` profile. It checks
an independent AIR-to-model correspondence theorem in Lean and replays the
handwritten proofs against the fresh generated definitions. False proof clients
import that exact freshly compiled proof module. `report.json` and `evidence.tar`
retain inputs, hashes, process receipts and results. The checked-in generated
file keeps its historical provenance.

The contract is for the captured callee's **slice interface**, not the pointer
wrapper used to request capture. Calling a looping callee is still outside the
direct-call profile. `--specialized-source` admits this standalone concrete body;
it does not prove all generic specializations or validate the wrapper by proxy.

This is a real library body under explicit model assumptions. It is not a proof
of source-to-AIR preservation, the native backend, native stack capacity or Rust's
ownership discipline. The [admission specification](../../docs/admission.md)
describes those boundaries.
