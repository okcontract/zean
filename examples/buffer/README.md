# Prove a Zig buffer update safe in Lean

This tutorial verifies a function that replaces one element in a buffer. It
proves that execution either updates exactly the selected word, rejects an
out-of-range index without changing the caller's heap, or encounters modeled
stack exhaustion without changing that heap. An off-by-one edit demonstrates
both an invalid access and a violation of a smaller buffer's boundary.

The three generated models come from real native AIR captures with Zig 0.17.1.
Handwritten Lean 4.35.0 proofs live in separate files. These are proofs about
the captured models under explicit storage assumptions; source and compiler
correspondence remain trusted. See [what this proves](#what-this-proves).

## Run it

With Zig **0.17.1** and the repository's Lean **4.35.0** toolchain installed,
run from the repository root:

```sh
zig build buffer-run
zig build buffer
```

Both working versions report:

```text
changed=true, boundary rejected=true, words={ 10, 20, 99, 40 }
```

The caller supplies the middle two words of a four-word allocation. Updating
index 1 changes the third word; attempting index 2 is rejected. The neighboring
words remain untouched.

`buffer` runs native boundary and source-identity tests, builds the universal
proofs and concrete counterexamples, and checks that two intentionally false
proofs fail for the expected reason. It uses retained generated models and
needs no instrumented compiler. The broken Zig version is never executed
natively. `zig build test` includes the native controls, and `zig build check`
also checks the proofs and expected rejections.

## 1. Write the Zig program

[v1/buffer.zig](v1/buffer.zig) contains:

```zig
pub export fn replace(buffer: [*]u32, length: usize, index: usize, value: u32) bool {
    if (index < length) {
        buffer[index] = value;
        return true;
    }
    return false;
}
```

The exported interface passes a buffer as a pointer and length. Together they
describe a logical view of storage, which may be smaller than its backing
allocation. This form supports native export and capture without a Zig slice
in the exported ABI.

The caller must supply live, writable `u32` storage covering the declared view.
A pointer and a length alone cannot establish that fact. The function validates
the index; it cannot validate a fabricated pointer or an exaggerated length.

Replacement never reads the old element. The safety proof therefore also
permits initially uninitialized buffer elements. For the separate theorem
about the exact resulting list, we assume that the original contents are
initialized and represent that list.

## 2. Capture and translate it

Follow the [toolchain guide](../../docs/toolchain.md) to obtain an instrumented
compiler report. This memory profile currently requires the supported **64-bit,
little-endian AArch64/macOS** target. The retained models and proofs can be
checked on other hosts; producing a new native capture has the target restriction.

Use new directories outside the checkout:

```sh
zig build capture -- \
  --toolchain /path/to/instrumented-build/report.json \
  --source examples/buffer/v1/buffer.zig \
  --root buffer.replace \
  --output /tmp/buffer-v1-capture

zig build run -- translate \
  --capture /tmp/buffer-v1-capture/report.json \
  --root buffer.replace \
  --profile memory \
  --namespace Compiler.Tutorial.Buffer.V1.Generated \
  --output /tmp/buffer-v1-model
```

The output contains `Generated.lean` and `manifest.json`. The generated program
retains the comparison, pointer operation, store, returns and faults. It also
retains the stack slot Zig's AIR uses to save the pointer argument. The model
accounts for this allocation and removes the slot on return.

## 3. State the contract and prove it

| Handwritten file | What to read |
| --- | --- |
| [Spec.lean](../../lean/Compiler/Tutorial/Buffer/Spec.lean) | Independent list update and the allowed memory effects |
| [Proofs.lean](../../lean/Compiler/Tutorial/Buffer/Proofs.lean) | Universal safety, correctness and preservation theorems |
| [Verification.lean](../../lean/Compiler/Tutorial/Buffer/Verification.lean) | Contract checked using the generic `Std.WP` verifier |
| [Contracts.lean](../../lean/Compiler/Tutorial/Buffer/Contracts.lean) | Consequences of memory frames for this API |
| [Broken/Proofs.lean](../../lean/Compiler/Tutorial/Buffer/Broken/Proofs.lean) | Concrete counterexamples and the repaired outcomes |

`replace_safe` quantifies over either working version, any valid caller state,
any writable view within a declared `u32` array, every 64-bit index and every
32-bit replacement value. Its inputs do **not** assume a successful pointer
operation, store or invocation. The proof derives access and write success from
allocation geometry, alignment, permissions and the bounds guard.

Its result establishes:

- Only the specified successful return or modeled allocation exhaustion occurs;
  unallocated access, uninitialized reads and memory-validity faults are excluded.
- The resulting state remains valid and the view stays writable.
- Every unrelated allocation and every word observation outside the logical view
  remains unchanged.
- A replacement changes exactly one word; rejection and exhaustion preserve the
  entire caller heap.

`replacement_correct` connects successful execution to the independent list
specification: the Boolean is exactly `index < length`, and the contents are
`items.set index value`. Outside the list, `List.set` leaves it unchanged.
`other_words_unchanged` preserves every other word observation, even an
uninitialized observation. `fault_is_exhaustion` rules out all other modeled
faults, rather than merely proving that the interpreter detects them.

Stack exhaustion is explicit because the AIR allocates a local slot. It is a
resource outcome of the model, not a new error return in the Zig API or evidence
about actual platform stack limits. Cleanup preserves the caller heap but retains
allocation-history counters; the entire interpreter state need not be unchanged.

The proof uses the library's `air_vcgen` tactic to generate obligations from the
actual program data, then `air_finish` to discharge them with generic memory
rules and the API's three allowed outcomes:

```lean
  have initialFrame := StackFrame.refl state valid
  cases version <;> dsimp only [program, V1.Generated.fn_replace, V2.Generated.fn_replace, arguments, size]
  all_goals air_vcgen
  air_finish [Spec.exhausted, Spec.rejected, Spec.replaced]
```

The verifier contains no buffer function names or register numbers. Its rules
are proved against the interpreter; `finite_sound` transfers the contract to
the finite execution interface. Bounds and heaps remain symbolic. Lean checks
the resulting proof terms without extra axioms or unchecked native evaluation.
The client sets explicit heartbeat and recursion budgets for proof checking.

[BufferExecution.lean](../../lean/Compiler/Baselines/BufferExecution.lean) retains the
earlier manual development for comparison. The public proofs and fresh replay
do not import it.

## 4. Make an incorrect update

Change `<` to `<=`, as in [broken/buffer.zig](broken/buffer.zig), then recapture
and translate it. The edit is within the supported fragment, so translation
succeeds. **Admission is not a safety proof.**

The new comparison admits `index == length`. Lean verifies two counterexamples
from the same valid, initialized three-word allocation:

| Supplied view | Index | Broken model's behavior |
| --- | --- | --- |
| All three words | 3 | Reaches a memory-validity fault |
| Just the middle word | 1 | Returns `true` and overwrites the following word |

The second case shows why physical allocation bounds are insufficient: the
write is inside allocated storage but outside the caller's logical buffer.

[BrokenProof.lean](BrokenProof.lean) incorrectly claims that the first input
returns `false`. [FrameProof.lean](FrameProof.lean) incorrectly claims that the
neighbor is preserved. Both fail, and `zig build buffer` requires those failures.
The positive counterexample proofs establish that the initial heap is valid and
both views have writable storage.

## 5. Repair the guard and replay the proofs

[v2/buffer.zig](v2/buffer.zig) rejects invalid indices before accessing the buffer:

```zig
pub export fn replace(buffer: [*]u32, length: usize, index: usize, value: u32) bool {
    if (index >= length) return false;
    buffer[index] = value;
    return true;
}
```

The public contract stays the same. The captured control flow changes: version 1
writes in the true branch; version 2 returns early in that branch.
The same generic verification proof handles both shapes. The contract and its
memory and list consequences are shared. After a source update, regenerate
program data and recheck the contract; change the contract or invariants only
when the intended behavior requires it.

To reproduce the lifecycle against **fresh generated definitions**:

```sh
zig build buffer-regenerate -- \
  --toolchain /path/to/instrumented-build/report.json \
  --output /tmp/new-buffer-evidence \
  --check
```

The command captures all three stages, compares ordinary and capture-enabled
object bytes, translates them, and replays handwritten proofs and negative
controls against the new definitions. It strips local tutorial imports and
supplies the fresh definitions directly, preventing substitution of retained
generated modules. Lean processes run sequentially with two workers each.

`--check` also compares source identities and complete programs with the
retained modules. Capture metadata may differ. Omit `--check` while reviewing
a source change. If a proof no longer applies, the command fails and retains
candidate models and diagnostics. Update the handwritten proofs as required
and rerun into a new directory.

After reviewing a successful replay, copy the generated candidates into their
version directories, keeping proofs separate. For example:

```sh
cp /tmp/new-buffer-evidence/v2-translation/Generated.lean \
  lean/Compiler/Tutorial/Buffer/V2/Generated.lean
zig build buffer
```

The evidence includes source/proof inputs, AIR, native objects, manifests, logs,
`Replay.lean`, a hash inventory and `evidence.tar` with a checksum. Compiler
caches are excluded. The full release gate includes this replay alongside
the counter lifecycle and fresh memory/slice audits.

## What this proves

The theorem establishes memory safety and the specified update behavior for
these generated models under their caller contracts. A caller can discharge
the storage assumptions and use the preservation and content guarantees in
its own proof.

This is not a memory-safety guarantee for arbitrary Zig programs. Live storage,
declared lengths and the absence of concurrent mutation are caller obligations.
General allocator implementations, foreign calls and concurrency are outside
this example. Capture and translation, target layout correspondence and native
compilation remain trusted; source-validity coverage is incomplete. Matching
object bytes and hashes support reproducibility, not a proof of compiler
correctness. See [architecture and trust](../../docs/architecture.md).
