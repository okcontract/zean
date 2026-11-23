# Verify a buffer update

The function writes one word within a caller-supplied view. Its proof covers
a successful update, an out-of-range index, and modeled allocation exhaustion.

```sh
zig build buffer-run
zig build buffer
```

Both working versions print `changed=true, boundary rejected=true, words={ 10, 20, 99, 40 }`.
The caller supplies the middle two words of a four-word allocation. Index 1
changes the third word and index 2 is rejected. `buffer` uses retained AIR
models to check source identities, native boundary cases, universal Lean
proofs, and two expected proof failures.

## Contract

The exported ABI takes a many-pointer and a length. The caller must supply
live, writable `u32` storage for the declared extent. The guard checks the
index. Since the store never reads the old word, the safety proof permits
uninitialized contents. The list-update theorem assumes initialized contents
representing the original list. [Zig source](v1/buffer.zig)

`replace_safe` covers every valid caller heap, writable view, 64-bit index,
and 32-bit value. It derives access and store success from the allocation
geometry, permissions, and guard. The result preserves heap validity, the
writable view, and observations outside the view. Successful replacement
changes exactly one word. Rejection and modeled exhaustion preserve all
caller memory. [Contracts](../../lean/Compiler/Tutorial/Buffer/Contracts.lean) ·
[Public proofs](../../lean/Compiler/Tutorial/Buffer/Proofs.lean)

The generated AIR stores a pointer argument in a private stack slot. The
model accounts for its allocation and cleanup. `fault_is_exhaustion`
excludes other faults. `replacement_correct` connects a successful result
to `index < length` and `items.set index value`. `other_words_unchanged`
covers initialized and uninitialized observations.
[Independent specification](../../lean/Compiler/Tutorial/Buffer/Spec.lean)

The same proof handles both working versions. It invokes `air_vcgen`, uses
`air_word_finish` with the three outcome lemmas, and applies `finite_sound`
to the interpreter. [Verification proof](../../lean/Compiler/Tutorial/Buffer/Verification.lean)

## Check the off-by-one edit

Changing `<` to `<=` admits index `length`. The model has two witnesses in a
valid three-word allocation.

| View | Index | Result |
| --- | --- | --- |
| All three words | 3 | Memory-validity fault |
| The middle word | 1 | Returns `true` and overwrites the following word inside the allocation |

Lean checks both witnesses. `zig build buffer` also requires the false
return and frame claims to fail. The repair returns early when
`index >= length` and keeps the same public contract.
[Broken source](broken/buffer.zig) · [Witnesses](../../lean/Compiler/Tutorial/Buffer/Broken/Proofs.lean) ·
[Repaired source](v2/buffer.zig)

## Regenerate and replay

Fresh capture for this memory profile uses AArch64 macOS with LLVM.
[Toolchain setup](../../docs/toolchain.md)

```sh
zig build buffer-regenerate -- \
  --toolchain /path/to/toolchain/report.json \
  --output /tmp/buffer-evidence \
  --check
```

Replay uses fresh definitions for all three versions and checks the retained
source identities and models. For a source edit, omit `--check`, review the
candidates and diagnostics, then copy each approved `Generated.lean` from
`*-translation/` to its version directory. Rerun `zig build buffer`. The
evidence includes AIR, object comparisons, receipts and `evidence.tar`.
[Manual capture](../../docs/native-tooling.md#capture-and-translate)

The historical instruction-by-instruction proof remains a regression
baseline. The active proof uses the generic verifier. Caller storage,
native stack resources, capture fidelity, and compiler preservation are
separate obligations. [Baseline](../../lean/Compiler/Baselines/BufferExecution.lean) ·
[Evidence scope](../../docs/evidence.md)
