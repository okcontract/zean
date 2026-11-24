# Ziglings memory contracts

With Zig 0.17.1 and Lean 4.35.0 installed, run this from the Zean checkout.

```sh
zig build ziglings
```

The target runs two official Ziglings corrections natively, checks the
derived kernels against retained AIR models, and requires two false proofs
to fail. Use `zig build ziglings-upstream` for the native exercises alone
or `zig build ziglings-proofs` for the proof checks.
[Upstream revision, patches, and license](upstream/README.md)

## Initialize both characters (038)

Exercise 038 prints two characters after initializing only the first.
The official correction initializes the second. The derived kernel
isolates the same pattern using two gold values.
[Original exercise](upstream/038_structs2.zig)

```zig
pub export fn initialize_pair(gold: [*]u32, first: u32, second: u32, index: usize) u32 {
    gold[0] = first;
    gold[1] = second;
    return gold[index];
}
```

The contract assumes a valid heap, two writable words, and `index < 2`.
The original contents may be uninitialized. On success, the model returns
the selected new value and preserves heap validity. Modeled exhaustion
remains an allowed fault. The `missing_character` control omits the second
store. Reading index 1 then faults on uninitialized memory, with the first
store still visible. [Initialization proof](../../lean/Compiler/Tutorial/Ziglings/Initialization.lean) ·
[Controls](../../lean/Compiler/Tutorial/Ziglings/Controls.lean)

## Give the pointer an extent (054)

The official correction supplies `zen_manyptr[0..21]` for the 21-byte
phrase. The derived kernel takes a runtime extent so the proof can cover
arbitrary byte contents. [Original exercise](upstream/054_manypointers.zig)

```zig
pub export fn phrase_byte(bytes: [*]const u8, length: usize, index: usize) u8 {
    if (index >= length) return 0;
    return bytes[0..length][index];
}
```

The caller supplies a live, initialized region of `length` bytes, possibly
readonly, with length and index fitting a 64-bit `usize`. The model returns
the indexed byte or zero at and beyond the extent, preserving caller memory.
The zero-length path reads no bytes. The proof uses `air_vcgen` and
`air_read_finish`. Its `grind` settings bound proof search.
[Bounds proof](../../lean/Compiler/Tutorial/Ziglings/Bounds.lean)

The `exaggerated_byte` control adds one to the length. A checked execution
supplies three bytes and requests the fourth. It reaches `.memoryValidity`.
The fixed-length upstream expression has a separate admission and
correspondence check. [Compatibility gate](../compatibility/README.md)

## Recapture and replay

```sh
zig build ziglings-regenerate -- \
  --toolchain /path/to/toolchain/report.json \
  --output /tmp/ziglings-evidence \
  --check
```

Replay captures all four kernel functions, checks correspondence and the
retained source and program identities, and runs both positive and negative
proof clients on fresh definitions. For an edit, omit `--check`, inspect
the candidate and fix any proof that no longer applies. Copy the reviewed
`ziglings-translation/Generated.lean` to the tutorial's model path and
rerun `zig build ziglings`. [Toolchain setup](../../docs/toolchain.md) ·
[Retained model](../../lean/Compiler/Tutorial/Ziglings/Generated.lean)

The contracts cover the captured kernels, with supplied storage assumptions
and modeled resource outcomes. The official exercises, including printing,
have their separate native tests. Native stack resources and compiler
preservation need separate evidence. [Proof pipeline](../../docs/architecture.md)
