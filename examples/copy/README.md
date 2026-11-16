# Verify a copy loop with contracts and an invariant

This example is a second client of the generic verifier used by the
[buffer tutorial](../buffer/README.md). It copies initialized `u32` words from a
readonly source into writable storage. The destination need not be initialized.
Run the native tests, universal Lean proofs and expected proof failures with:

```sh
zig build copy
```

Zig **0.17.1** and Lean **4.35.0** are required. The checked-in generated module
comes from a native AIR capture; running these checks does not require an
instrumented compiler.

## The Zig program

[`copy.zig`](copy.zig) contains the loop and a small helper:

```zig
inline fn copyWord(destination: *u32, source: *const u32) void {
    destination.* = source.*;
}

pub export fn copy(destination: [*]u32, source: [*]const u32, length: usize) void {
    var index: usize = 0;
    while (index < length) : (index += 1) {
        copyWord(&destination[index], &source[index]);
    }
}
```

The file also exports `copy_word`, a separately captured entry to the helper.
The inline helper becomes loads and stores in the captured caller. Runtime
function calls are not part of the admitted memory interpreter.

Many-item pointers do not carry a length. The caller must establish the extent
of both views, writable destination storage, initialized source words and
disjoint source/destination ranges. Disjoint subviews of the same allocation
are allowed. The helper's single read-before-write contract permits aliasing;
the loop's stronger source-preservation contract requires disjoint ranges.

## Translate both functions

Build an instrumented compiler using the [toolchain guide](../../docs/toolchain.md),
then capture and translate into new directories outside the checkout:

```sh
zig build capture -- \
  --toolchain /path/to/instrumented-build/report.json \
  --source examples/copy/copy.zig \
  --root copy.copy --root copy.copy_word \
  --output /tmp/copy-capture

zig build run -- translate \
  --capture /tmp/copy-capture/report.json \
  --root copy.copy --root copy.copy_word \
  --profile loops \
  --namespace Compiler.Tutorial.Copy.Generated \
  --output /tmp/copy-model
```

[`Generated.lean`](../../lean/Compiler/Tutorial/Copy/Generated.lean) is emitted
program data, including three local stack slots and the structured loop. It
records source, AIR and capture-report identities. Handwritten contracts and
proofs live in separate files.

## State the contract and invariant

[`Contracts.lean`](../../lean/Compiler/Tutorial/Copy/Contracts.lean) defines:

- `Completed`: unit result, valid heap, copied destination contents, unchanged
  source contents, and preservation of caller memory outside the target view.
- `Exhausted`: only modeled out-of-memory failure, with valid caller storage,
  source contents and surrounding memory preserved.
- `loopInvariant`: `index ≤ length`, an initialized copied prefix, valid source
  and destination storage, saved parameter/counter bindings, and a frame relation.

The invariant has register bindings specific to this capture. The generic
library handles their meaning and the control flow; it has no knowledge of the
copy function, its instruction numbers or its loop label. A changed capture
may require updating these client bindings.

The [verification proof](../../lean/Compiler/Tutorial/Copy/Verification.lean)
unfolds the generated program, invokes `air_vcgen [loopInvariant, ...]`, and
discharges its conditions with `air_word_finish [exhausted, completed]` and
explicit proof-search limits. The two supplied lemmas connect the generic
memory effects to this API's postconditions. They do not execute instructions.

The [public theorems](../../lean/Compiler/Tutorial/Copy/Proofs.lean) connect that
contract to the existing interpreter. `copy_safe` holds for **every fuel value**;
`copy_correct` states the complete postcondition whenever execution returns.
No successful allocation, read or write is assumed. This is safety and partial
correctness; a termination proof and a native resource bound remain separate.

## Reuse the helper contract

[`Helper.lean`](../../lean/Compiler/Tutorial/Copy/Helper.lean) proves the exported
helper against its generated definition. It also specifies the inline load/store
fragment with arbitrary register identities. `word_then_contract` reuses that
proof with `Control.Verification.prefix_contract` before an arbitrary continuation.
The caller proves the continuation from the helper's memory effect without
unfolding the helper's instructions. The loop proof currently verifies the
inlined instructions directly through the same generic primitive rules.

## Check the missing assumptions

The [model controls](../../lean/Compiler/Tutorial/Copy/Controls.lean) are checked
by kernel evaluation, independently of the universal contract:

| Control | Expected observation |
| --- | --- |
| Readonly source and unwritten destination | Successful copy; both neighboring sentinels retained |
| Only the first source word initialized | Uninitialized-read fault after the first write, which remains visible |
| Length larger than the available source | Memory-validity fault |
| Overlapping source and destination | Execution succeeds but changes the source contents |

Three intentionally false proof files assert successful execution or source
preservation for the invalid cases. `zig build copy` requires their rejection
with the expected diagnostic. The native tests execute only valid cases,
including an empty copy, disjoint subviews and the helper's permitted alias.

These controls distinguish memory safety from functional correctness. Overlap
need not fault, but this forward loop cannot satisfy the advertised source and
destination postconditions when ranges overlap.

## Change and replay

After editing Zig, regenerate the model and recheck the contracts. For example,
changing `< length` to `<= length` adds a boundary access; the current invariant
will no longer discharge that access obligation. A source change may also alter
the saved-register bindings even when the mathematical contract stays the same.
The [buffer tutorial](../buffer/README.md) retains a complete broken-and-repaired
update lifecycle; this example focuses on loops and composition.

To recapture the unchanged copy source and check all proofs against the fresh
definitions, run:

```sh
zig build copy-regenerate -- \
  --toolchain /path/to/instrumented-build/report.json \
  --output /tmp/copy-evidence \
  --check
```

This compares both complete programs, replays the proofs without importing the
checked-in generated module, and requires all three negative proofs to fail.
Its archive contains input files, captures, object comparisons, translations
and process receipts. Source/compiler correspondence is still a separate trust
boundary: the model proof and matching object bytes do not prove native Zig
memory safety or whole-compiler correctness.

## Following generated locals

The loop invariant selects its live locals and loop label from the generated
program using `MemoryAir.Bindings`. Each selection has a checked bounds proof;
`air_binding%` evaluates it once and retains a checked equality. The invariant
uses `Binding.Saved` for the saved pointers and mutable index, so SSA renumbering
does not require copying new instruction numbers into the proof. A change to
the set or role of locals still needs review, as do the invariant's explicit
stack lifetime assumptions. This machinery is part of the generic library.
