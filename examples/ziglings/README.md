# From Ziglings fixes to checked memory contracts

Ziglings 038 and 054 ask two small questions with large consequences: **has
this value been initialized, and how much memory does this pointer describe?**
This tutorial turns those lessons into executable Zig kernels, translates
their analyzed code into Lean, and checks contracts about their execution.

The examples demonstrate substantial proof automation after a developer writes
a contract. They do not turn arbitrary Zig source into an automatic safety
verdict. The proofs below concern captured runtime kernels derived from the
exercises, with explicit caller assumptions and translation boundaries.

## Run it

Install Zig **0.17.1** and the pinned Lean toolchain, then run from the repository
root:

```sh
elan toolchain install leanprover/lean4:v4.35.0
zig build ziglings
```

This runs the officially corrected upstream exercises, tests the runtime
kernels, checks source identities and Lean proofs, and requires two deliberately
false proof clients to fail. Checked-in models come from actual AIR captures;
running this command does not require an instrumented Zig compiler.

For individual checks:

```sh
zig build ziglings-upstream
zig build ziglings-proofs
```

### What is pinned?

The upstream revision is [Ziglings `v0.17.0`, commit
`f594c3f60940506a6b0c8a920e4f440a6e2962dc`](https://codeberg.org/ziglings/exercises/src/commit/f594c3f60940506a6b0c8a920e4f440a6e2962dc).
Upstream has no `v0.17.1` tag. We record the source revision and **Zig 0.17.1
compiler compatibility separately**, and check the latter by compiling and
running these two official corrections. This is not a claim about every
exercise in that revision.

The [unchanged upstream files](upstream/README.md), official patches and MIT
license are retained. [`upstream.zig`](upstream.zig) records their hashes and
applies the corrections explicitly. The unsafe 038 baseline is never executed
by our native test targets.

## 038: writable memory is not initialized memory

[Exercise 038](upstream/038_structs2.zig) declares two RPG characters with
`undefined`, initializes the first, then prints both. The correction initializes
the second character too. Having space for two characters does not give the
second character a value.

The runtime kernel in [`ziglings.zig`](ziglings.zig) isolates that issue using
the two characters' gold fields:

```zig
pub export fn initialize_pair(gold: [*]u32, first: u32, second: u32, index: usize) u32 {
    gold[0] = first;
    gold[1] = second;
    return gold[index];
}
```

The contract assumes a valid modeled heap, a writable view of two `u32` slots,
and `index < 2`. It makes **no assumption about the slots' initial contents**.
For arbitrary `first` and `second`, successful execution returns the selected
new value and leaves a valid heap. Invalid accesses and uninitialized reads
are excluded. Modeled stack allocation exhaustion remains an explicit allowed
failure.

[`Initialization.lean`](../../lean/Compiler/Tutorial/Ziglings/Initialization.lean)
states that contract and invokes `air_vcgen` followed by the word-memory
automation. The verifier processes the generated instructions, including the
compiler's stack temporaries. It knows no exercise name or instruction number.
[`Proofs.lean`](../../lean/Compiler/Tutorial/Ziglings/Proofs.lean) applies the
framework's soundness theorem to connect the contract to interpreter execution.

The neighboring `missing_character` kernel omits `gold[1] = second`. On an
initially unwritten two-slot allocation with index 1, Lean checks that execution
returns `uninitialized`. It also checks that the first write already happened:
failure does not roll back reached effects. The false claim that this execution
returns the second value must fail to compile.

This is a proof about the initialization pattern, **not the complete original
`Character` program**. Enum-bearing struct translation and `std.debug.print`
are not covered by this kernel's memory contract. Native execution of the
official correction checks those original programs separately.

## 054: a pointer does not carry an extent

[Exercise 054](upstream/054_manypointers.zig) starts with the 21-byte phrase
`Memory is a resource.` and converts an array pointer to a many-pointer.
Assigning that many-pointer directly to a slice is rejected by Zig: a slice
also needs a length. The official correction supplies `zen_manyptr[0..21]`.

A length makes the expression type-correct; its truth still needs a caller
contract. Our kernel makes the extent and requested index runtime inputs:

```zig
pub export fn phrase_byte(bytes: [*]const u8, length: usize, index: usize) u8 {
    if (index >= length) return 0;
    return bytes[0..length][index];
}
```

The contract describes `length` initialized bytes in a live region starting at
the supplied address. `length` and `index` fit a 64-bit `usize`. The allocation
may be readonly. For every such caller state and byte sequence, the generated
model returns the indexed byte when `index < length`, and zero otherwise;
caller memory remains unchanged. The zero-length case needs no element read.

[`Bounds.lean`](../../lean/Compiler/Tutorial/Ziglings/Bounds.lean) uses the same
generic VC generator with optional readonly-view rules. Those library rules
derive the checked slice extent and selected pointer from initialized element
reads. They are parameterized by element type and layout, so they are not a
special case for this phrase or for bytes.

The execution proof uses this pattern:

```lean
have initialFrame := StackFrame.refl state valid
dsimp only [Generated.fn_phrase_byte, ReadView.buffer, bytes]
air_vcgen
air_read_finish (gen := 16) (ematch := 10) (verbose := false) [bytes, byte]
```

The integer-valued contract matches the interpreter's scalar representation;
a short wrapper exposes natural-number lengths and indices to callers.
The explicit `grind` limits configure proof search. They do not bound program
inputs or permit unchecked results when search fails.

The broken `exaggerated_byte` kernel adds one to the supplied extent. A
kernel-checked counterexample supplies exactly three allocated bytes and asks
for the fourth. The model returns `memoryValidity`; inventing a larger slice
does not create storage. This control executes only in Lean.

The adaptation uses a runtime length to prove an input-general contract for
this kernel. The memory route now also admits the fixed-length upstream
expression's `array_to_slice` operation, retaining its static extent.
The [compatibility gate](../compatibility/README.md) checks that route with fresh
capture and AIR correspondence. The proof here still covers the runtime-length
kernel; the unchanged upstream expression and its printing code receive no
memory-safety theorem from this example.

## Translate and replay after an edit

Keep Zig code, generated program data and handwritten proofs separate:

| File | Role |
|---|---|
| `ziglings.zig` | Corrected kernels and explicitly broken variants |
| `lean/Compiler/Tutorial/Ziglings/Generated.lean` | Translator output; never edit by hand |
| `Initialization.lean`, `Bounds.lean` | Handwritten contracts and automated proofs |
| `Proofs.lean` | Connection to execution semantics |
| `Controls.lean` | Concrete success and failure witnesses |
| `InitializationProof.lean`, `BoundsProof.lean` | False clients that must reject |

Fresh capture requires an instrumented Zig toolchain report; see the
[toolchain instructions](../../docs/toolchain.md). Keep evidence outside the
checkout. With that report available:

```sh
zig build ziglings-regenerate -- \
  --toolchain /absolute/path/to/toolchain/report.json \
  --output /absolute/path/to/new-ziglings-evidence \
  --check
```

This captures all four functions, compares their complete generated programs
and source identities with the retained versions, checks AIR-to-model
correspondence certificates, and replays the handwritten proofs against the
**fresh** definitions. Negative clients import that same fresh replay. The
evidence report records which checks ran and retains the logs.

To explore an update, remove the second initialization, or change the slice
extent to `length + 1`. These edits are already represented by the two broken
kernels. Their captured behavior changes and the original success claims fail;
the concrete counterexamples explain why. Restoring the correct write or
extent restores the contract.

For a new edit to a corrected kernel, run regeneration **without `--check`**
into a new directory. Proof replay still has to succeed. Review the generated
program and any necessary contract changes, copy
`ziglings-translation/Generated.lean` into its tracked location, and run
`zig build ziglings` followed by regeneration with `--check`. An unrelated
comment edit changes the source hash too; do not repair identities by hand.

If proof replay fails, the failed evidence directory retains the new generated
model and diagnostics. Review that model before updating a proof. Weakening a
contract merely to hide an invalid access is not a repair.

## How automatic is this?

For these supported, loop-free kernels, the developer supplies the storage
contract and desired result. The framework generates obligations from actual
program data, and reusable rules discharge initialization, bounds, permissions,
temporary-storage and cleanup obligations. The final proof terms are checked
by Lean 4.35.0's kernel; there are no added axioms or unchecked evaluation
shortcuts.

This is **contract-driven proof automation**, not contract inference. A new
supported program can use the same machinery without adding function-specific
logic to the verifier. Harder programs may need additional general memory
lemmas, mathematical arguments, [loop invariants](../copy/README.md), or
[helper contracts](../calls/README.md). Unsupported AIR still rejects.

The theorems allow the model's stack allocation to report `outOfMemory`. They
exclude memory-access faults under the contract, but do not prove native stack
resource availability. Concrete positive controls establish that the example
executions actually complete; they are not a universal resource theorem.

Finally, a checked proof of a translated model is not a proof of the whole Zig
compiler or every source-validity obligation. The correspondence certificates
check the supported AIR-to-model relation; source admission, capture, and native
code generation remain trust boundaries. No runtime checker is inserted into
the native executable. See [architecture and trust](../../docs/architecture.md).
