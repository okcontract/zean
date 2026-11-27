# Prove a contract on a generated model

Keep the generated model and your proof in separate modules. Use the pinned
Lean 4.35.0 toolchain. Zean's verifier uses `Std.WP` and enables the
experimental `vcgen` tactic locally through `air_vcgen`.
[Client setup](../examples/client/README.md) · [Lean module map](architecture.md#lean-models)

## Write and check a contract

1. Generate the model with a supported profile. Use `memory` for finite code,
   `loops` for a loop, or a call profile for retained direct calls.
   [Profile limits](architecture.md#supported-routes)
2. Import the generated module and `Compiler.ZigAir.Verify.Core`. Add the
   domain you need, such as `Verify.Words` for word views, `Verify.Slices`
   for writable slices, `Verify.Reads` for readonly views, `Verify.Bytes`
   for byte ranges, copies, and overlapping moves, or `Verify.Records` for complete record fields.
3. State the precondition, successful result, and allowed faults. Give each
   loop label an invariant about the live locals and memory.
4. Prove a `Std.WP.Triple` over `MemoryAir.Verify.Invocation.mk program args invariants`.
   Unfold the generated definition and argument construction, then use
   `air_vcgen` and `air_finish [yourFacts]` or `air_word_finish [yourFacts]`.
   Finish any remaining goals with ordinary Lean tactics.
5. Apply `MemoryAir.Verify.sound` for `runFuel` at any fuel, or `finite_sound`
   for a finite program's `run`. For a loop-free contract, pass
   `program.enableLoops` and an everywhere-false invariant.

The buffer proof unfolds each captured version and describes the same three
outcomes through the `Spec` lemmas. [Buffer verification](../lean/Compiler/Tutorial/Buffer/Verification.lean)

```lean
have initialFrame := StackFrame.refl state valid
cases version <;> dsimp only
  [program, V1.Generated.fn_replace, V2.Generated.fn_replace, arguments, size]
all_goals air_vcgen
air_word_finish [Spec.exhausted, Spec.rejected, Spec.replaced]
```

For byte copies, use `air_byte_vcgen` and `air_byte_finish [yourFacts]`.
`air_byte_reads`, `air_byte_writes`, and `air_byte_subviews` apply rules to
initialized reads, writes, and checked subviews. Fallback specifications use
the actual evaluator and leave the operation's obligations in Lean.
[Byte-memory controls](../lean/Compiler/Tests/ZigAir/MemoryByteAutomationControls.lean)

## Memory and fault assumptions

`Safe` permits only modeled `.outOfMemory` faults. Use `FaultFree` to exclude
every fault, or state what the heap must preserve on a permitted failure.
`Terminates` requires a finite result. `Completes` also requires success and
the stated postcondition. `completes_of_contract` uses a fault-free contract
and termination. `finite_completes` supplies structural termination for
finite code.

`Memory.AllocationRoom cursor type` states the modeled address budget.
`AllocationRoom.of_budget` includes alignment padding, and `allocate_total`
and `allocate_no_fault` discharge allocation obligations. Writes preserve
the budget, and cleanup retains the allocation history. `air_resources`
carries address-counter bounds through allocations and stores. Physical
stack capacity needs a native argument.
[Resource controls](../lean/Compiler/Tests/ZigAir/MemoryResourceControls.lean)

| Predicate | Assumption or guarantee |
| --- | --- |
| `State.valid` | Consistent allocation metadata and stored values |
| `WordArray.Writable` | Live writable storage for a logical word view |
| `WordArray.Readable` | Live storage covering the word view |
| `WordArray.Represents` | Initialized words corresponding to a list |
| `WordArray.Initialized` | Initialized words with arbitrary contents |
| `ReadView.BaseAccessible` | Live, aligned many-pointer base. Use `element_of_load` with a successful load at the selected index for a partially initialized table |
| `ReadView.Represents` | Initialized readonly elements of a given type, layout, and extent |
| `ReadView.Writable` | Writable declared leaf elements in typed slice geometry, including uninitialized destinations |
| `ByteArray.Region` | Live byte storage and extent with the requested permissions, including fields in complete records |
| `ByteArray.ByteField` | Static byte-leaf geometry in a complete owner |
| `ByteArray.Represents` | Initialized bytes for a logical view |
| `ByteArray.CopyPost` | Copied contents, preserved source, and preserved reads outside the destination prefix |
| `RootWritable` | Writable storage for a complete typed object or local slot |
| `HeapFrame` | Caller allocations and words outside the target view are preserved |
| `StackFrame` | Private allocations preserve caller memory |
| `BorrowedFrame` | Target-view writes and private allocations preserve other caller memory |

These predicates describe sequential execution. State alias restrictions in
the contract. Disjoint subviews may share a backing allocation. For readonly
views, `air_read_finish [yourFacts]` uses the supplied contents function and
extent to justify initialized reads. Each read requires a nonempty,
in-bounds extent.
[Ziglings readonly proof](../examples/ziglings/README.md) ·
[Ownership and escape](lifetimes.md)

## Loops and helpers

A loop invariant sees the label, SSA environment, and memory state.
`air_vcgen` generates obligations at entry and back edges. The copy invariant
describes saved bindings, a copied prefix, and a frame for surrounding memory.
[Copy contract](../lean/Compiler/Tutorial/Copy/Contracts.lean)

`Control.Verification.Fragment` describes typed inline instructions.
`prefix_contract` composes a proved fragment with a continuation, preserving
faults and reached effects. The copy helper demonstrates the rule. The loop
proof uses the generic instruction rules on its inlined body.
[Inline helper proof](../lean/Compiler/Tutorial/Copy/Helper.lean)

For runtime calls, import `Verify.Machine`. State a triple over
`verify functions root args invariants`, use `machine_vcgen [helper_specs]`,
then expose client definitions with `machine_normalize [definitions]`. Give
returned pointers a live storage capability in the postcondition. Recursive
calls require a proof that justifies recursive hypotheses, such as an execution
invariant or induction. [Call-machine rules](call-machine.md) ·
[Source and specialization checks](admission.md#source-owners-and-calls)

Safety covers every finite observation, including prefixes of nonterminating
runs. Successful-result theorems give partial correctness. Use a separate
termination proof, such as the decreasing-rank rule in `ControlVerification`.

## Checked local bindings

`MemoryAir.Bindings` selects arguments, allocations, casts, and loop labels
from the generated program. `air_binding%` caches a selection with a
kernel-checked equality. `Binding.Saved` combines a register binding with
its stored value and, for mutable locals, its write capability. The invariant
still has to establish dynamic lifetime IDs, including conditional allocations.

Use `Bindings.resultOf code type operation` to select a typed producer with its
actual operands. Use the selected register in the next operation to follow
dataflow. An absent or ambiguous match yields `none`.

In a call-machine proof, select the receiving register with
`air_binding% ((Bindings.callResult caller.body calleeId).get (by decide)).register`.
A missing call or multiple calls to the same function yields `none`. When a
body has multiple matching calls, select the relevant subterm before looking
up its result.

For initialized writable slices, use `air_slice_finish [yourFacts]` after
`air_vcgen`. It normalizes slice selections and reads, preserves initialization
through writes and private allocations, and supplies witnesses for bounded
counter increments. [Standard-library example](../examples/stdlib_replace/README.md)

## Measuring proof cost

```sh
zig build benchmark -- --output /tmp/proof-cost
```

The defaults check the buffer, copy, calls, and standard-library replacement
proofs three times each. Use repeatable `--proof FILE` and `--repeat N` to
select others. Imported modules use their warm cache. Main files elaborate
afresh, serially, with one worker and a 4096 MiB limit.

Compare runs on the same machine with the same cache state. The report records
inputs, elapsed time, peak memory of the waited child, and lines in each main
file. This measures proof elaboration for those files. Transitive proof size,
aggregate memory, and native execution costs require separate measurements.
[Shared-context experiment](automation-measurements.md) ·
[Historical buffer proof](../lean/Compiler/Baselines/BufferExecution.lean)

## Prove a move that can overlap its source

With `Verify.Bytes`, use `ByteArray.move_refines` for the initialized contents
of a `ByteRange.move`. Supply live readable and writable regions, an initial
source snapshot through `Represents`, and a destination length within the
source. The destination represents the original source snapshot on return.
The heap frame preserves reads outside the destination. The proof tracks the
unread source bytes in the actual forward or backward traversal.
[Move contract](../lean/Compiler/ZigAir/MemoryByteMoveContracts.lean)
