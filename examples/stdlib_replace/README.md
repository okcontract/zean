# Verify the standard-library replacement loop

The wrapper makes Zig 0.17.1's `std.mem.replaceScalar(u32)` available for
capture. The model comes from the unchanged library implementation.
[Capture wrapper](replace.zig)

```sh
zig build stdlib-replace
```

The target checks native results, the standard-library source hash, Lean
proofs from the retained model, and two false proof clients.

The caller supplies a valid heap and an initialized writable word view.
The invariant relates the index to the extent and preserves initialization
and surrounding memory. `air_vcgen` and the slice rules derive the proof
obligations from the generated program. Checked selectors find the bindings
and loop label. [Model](../../lean/Compiler/Components/Replace/Generated.lean) ·
[Contract and proof](../../lean/Compiler/Components/Replace/Proofs.lean)

Every finite prefix excludes access, initialization, permission, arithmetic,
and malformed-program faults. Completion and modeled exhaustion preserve
the view and surrounding memory. Concrete controls check replacement values
and exhibit faults for uninitialized, readonly, and out-of-bounds views.
A write reached before a fault remains visible. The universal contract leaves
termination and the exact replacement list open.
[Controls](../../lean/Compiler/Components/Replace/Controls.lean)

## Recapture the specialization

```sh
zig build stdlib-replace-regenerate -- \
  --toolchain /path/to/toolchain/report.json \
  --output /tmp/stdlib-replace-evidence \
  --check
```

Replay selects `mem.replaceScalar__func_0` with its checked file owner and
concrete type mapping, translates it with `loops`, and checks correspondence
and proofs on the fresh model. The proof concerns this specialization's slice
interface. The pointer wrapper only requests capture. The replay retains
receipts and the checked-in file keeps its recorded capture hashes.
[Toolchain setup](../../docs/toolchain.md) ·
[Specialization admission](../../docs/admission.md#source-owners-and-calls)
