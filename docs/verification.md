# Verifying a supported program

The verification library consumes generated `MemoryAir.Program true` data or
the explicit call machine's function tables.
It has no table of tutorial function names, register numbers or loop shapes.
Contracts, invariants and application-specific mathematical facts belong in
your proof module. Generated code stays in its own module.

The library uses Lean **4.35.0** and its experimental
[`Std.WP`/`vcgen` framework](https://lean-lang.org/doc/reference/latest/releases/v4.35.0/).
`air_vcgen` enables the experimental tactic locally. Every resulting proof is
checked by Lean's kernel; unresolved obligations cause the proof to fail.

For the explicit call-stack interpreter, import `Verify.Machine` and use
`machine_vcgen` with checked helper summaries. The [caller/helper client](../examples/client/calls/README.md)
shows a fresh capture-to-proof workflow with no instruction numbers in its
proof. The [call-machine guide](call-machine.md) records its current automation
coverage, including client-supplied loop invariants. The workflow below uses
the established intraprocedural interface.

## Workflow

For library work, `zig build lean-core` checks the small API and
`zig build lean-framework` checks all optional domains. Use `zig build lean-examples`
for the proof clients and `zig build lean` for the complete library and admission
controls. The [module map](architecture.md#lean-models) explains their boundaries.

1. Capture your function and translate it with an appropriate supported profile,
   following the [toolchain guide](toolchain.md). Use `memory` for finite memory
   programs and `loops` for resumable loops. Unsupported operations still reject.
2. Import the generated module and `Compiler.ZigAir.Verify.Core` in a separate proof
   file. This public entry point supplies the common finite/loop verification
   API, inline composition and generic instruction automation. Import `Verify.Words`
   for word buffers, `Verify.Slices` for writable word slices, `Verify.Reads`
   for initialized readonly views of supported element types, `Verify.Bytes` for
   byte-array regions and bulk-copy contracts, `Verify.Records` for complete
   record fields, `Verify.Machine` for finite or looping callee contracts; these interfaces can
   be combined. `Verify.Lifetimes` supplies the
   separate [ownership and escape boundary models](lifetimes.md), without
   admitting native allocator or foreign calls. `Compiler.ZigAir.Verify` remains
   a convenience import for all domains.
3. Define an argument list, a precondition, a successful-result postcondition,
   and a fault postcondition. For loops, supply an invariant for each loop label.
4. State a `Std.WP.Triple` for `MemoryAir.Verify.Invocation.mk program args invariants`.
   Unfold the generated definition and argument construction, invoke
   `air_vcgen [yourInvariant]`, then use `air_finish [yourFacts]` or
   `air_word_finish [yourFacts]`. Ordinary Lean tactics can solve remaining goals.
   For saved byte slices and bulk copies, use `air_byte_vcgen` followed by
   `air_byte_finish [yourFacts]`. The [byte-memory controls](../lean/Compiler/Tests/ZigAir/MemoryByteAutomationControls.lean)
   exercise these rules on synthetic programs.
   The byte domains also provide `air_byte_reads`, `air_byte_writes` and
   `air_byte_subviews` for initialized reads, in-place updates and checked
   subviews. These tactics apply proved rules to reached operations; an
   unresolved obligation still fails verification.
5. Apply `MemoryAir.Verify.sound` to obtain a statement about `runFuel` for **any**
   fuel. Use `finite_sound` for a finite program's `run` interface. Regenerate and
   replay after changing Zig, keeping contracts and generated data separate.

For a `Program` without loops, pass `program.enableLoops` and an everywhere-false
invariant. These are real steps from the buffer client's proof:

```lean
have initialFrame := StackFrame.refl state valid
cases version <;> dsimp only
  [program, V1.Generated.fn_replace, V2.Generated.fn_replace, arguments, size]
all_goals air_vcgen
air_word_finish [Spec.exhausted, Spec.rejected, Spec.replaced]
```

See the complete [statement and imports](../lean/Compiler/Tutorial/Buffer/Verification.lean).
The three `Spec` lemmas express the API's effects; they contain no execution
tree traversal. The verifier derives bounds, reference typing, initialization,
permission, allocation, store, return and cleanup obligations from program data.
Generic fallback specifications retain the actual primitive evaluator, so an
operation without a specialized automation rule remains a proof obligation.

## What to put in a contract

`Safe program args state` means that every reached fault is `.outOfMemory`.
It rules out memory, initialization, malformed-program and scalar faults.
The exception postcondition can be stronger: use `False` to prohibit every
fault, or include heap and frame guarantees alongside the permitted fault.
Heap validity alone is not memory safety.

Use `FaultFree` when no fault, including modeled exhaustion, is permitted.
`Terminates` states that some finite run reaches a result; `Completes` requires
a successful result satisfying the postcondition. `completes_of_contract`
combines a fault-free contract with termination. For finite code,
`finite_completes` supplies structural termination automatically. A contract
allowing `.outOfMemory` cannot be passed to either completion rule.

`Memory.AllocationRoom cursor type` gives the exact allocation budget as an
arithmetic condition. `AllocationRoom.of_budget` supplies a conservative bound
including alignment padding; `allocate_total` and `allocate_no_fault` discharge
allocation obligations. Writes preserve this budget, and cleanup retains its
consumption. These are bounds on **modeled allocation history**, not a claim
about native stack capacity. The checked
[resource controls](../lean/Compiler/Tests/ZigAir/MemoryResourceControls.lean) prove
successful completion with room and exhibit a valid empty heap that exhausts
without room.

`MemoryResourceAutomation` adds `air_resources`, which carries address-counter
bounds across successful allocations and stores. For example, two temporary
slice headers consume at most 46 modeled address units, including alignment
padding. The bound supplies a sufficient condition for those allocations;
termination and the remaining program operations require their own proofs.

The memory predicates separate several obligations:

| Predicate | Obligation |
| --- | --- |
| `State.valid` | Consistent allocation metadata and stored values |
| `WordArray.Writable` | Live, writable storage for a logical word view |
| `WordArray.Readable` | Live storage and extent, without requiring write permission |
| `WordArray.Represents` | Initialized contents corresponding to a list |
| `WordArray.Initialized` | Every word in a view has initialized contents, without specifying their values |
| `ReadView.Represents` | Initialized readonly elements of a specified type, layout and extent |
| `ByteArray.Region` | Live declared byte storage, extent and requested write permission, including fields inside complete records |
| `ByteArray.ByteField` | Static byte-leaf geometry in a complete owner; excludes padding and integer representation casts |
| `ByteArray.Represents` | Initialized byte contents for a logical view |
| `ByteArray.CopyPost` | Copied contents, preserved source and reads outside the destination prefix |
| `RootWritable` | Writable root storage for a complete typed object or local slot |
| `HeapFrame` | Caller allocations and words outside the target view are preserved |
| `StackFrame` | Caller memory is unchanged under private invocation allocations |
| `BorrowedFrame` | Target-view writes and private allocations preserve other caller memory |

These are sequential capabilities and preservation relations. They permit
aliases and do not implement exclusive ownership, a Rust borrowing discipline,
concurrency or data-race freedom. State the required alias restrictions in your
contract; disjoint subviews may share an allocation.

For readonly views, `air_read_finish [yourFacts]` supplies checked slice
construction, element selection, initialized reads and preservation under
private stack allocation. The view's contents are specified by a function from
indices to values. An empty view asserts no reads; a program that accesses an
element still needs a nonempty, in-bounds capability. The
[Ziglings tutorial](../examples/ziglings/README.md) exercises this domain on
arbitrary byte contents and a separate word-initialization contract. Its
proofs contain no generated instruction numbers.

## Loops and helpers

Loop invariants receive a label, the current SSA environment and the memory
state. They must establish the live reference bindings as well as mathematical
facts. `air_vcgen` generates entry and preservation obligations for arbitrary
structured loops, branches, jumps and blocks. It does not infer invariants.
Capture-specific register bindings live in the client invariant and may need
updating after recompilation. The [copy invariant](../lean/Compiler/Tutorial/Copy/Contracts.lean)
combines a copied prefix with an initialized source and a frame relation.

`Control.Verification.Fragment` specifies a list of typed instructions.
`prefix_contract` composes its checked effect with any continuation, preserving
error states and reached effects. The copy helper's
[`word_then_contract`](../lean/Compiler/Tutorial/Copy/Helper.lean) exercises this
API without unfolding the helper in the caller proof. The captured loop itself
is checked directly through instruction rules; source helper boundaries do not
survive this inline capture.

Use `calls` or `call-loops` for direct runtime calls. Translation binds each
callee's name, owning source file, source hash and signature to its separately
captured body, and emits the finite call closure in dependency order. Recursion,
indirect calls, tail-call requests, missing bodies, unsupported specializations
and callees outside the explicit source closure reject. A callee must be finite;
a caller may have loops with `call-loops`.

Use `--declaration-source path/to/imported.zig` to select ordinary functions
captured from an imported file. Every selected root and callee is resolved in
its actual source owner; cached callees selected later as roots must also pass
the root checks. New capture records carry the compiler's source prototype
node. A concrete method in a type factory's instantiated namespace requires
this anchor to match a named function inside that factory in the hashed source.
`--certify /tmp/call-certificate` checks an independent Lean
interpretation of the entire emitted call closure, including the captured
callee bodies. The certificate checks AIR-to-model correspondence; source
hashes and declaration checks do not prove frontend correctness.

Call profiles emit the resumable call-stack representation by default. Import
`Verify.Machine`. Use `verify functions root args invariants`,
`machine_vcgen [helper_specs]` and `machine_normalize [clientDefinitions]`.
The [call-machine guide](call-machine.md) explains table lookup, checked helper
summaries, storage preservation and structural termination certificates.

The Calls tutorial uses checked `MemoryCallMachine.Contract` summaries.
Actual execution runs the callee body, including argument checks, cleanup and
reached effects. A typed pointer result alone does not establish its lifetime;
include its usable memory capability in the postcondition.

The `nested-calls` profile admits looping helpers. Suspension retains the complete
caller stack and reached state, without producing a return value or performing
cleanup. Safety quantifies over every finite observation. Termination requires
a separate proof; finite closures can use the checked structural certificate.

The `recursive-calls` profile admits direct self and mutual calls while retaining
the same invocation semantics. A proof must justify recursive hypotheses by
induction or an execution invariant. The finite structural termination
certificate still rejects a recursive cycle.

The earlier `MemoryCall` and `MemoryPartialCall` interpreters and their controls
are retained for regression coverage. Production translation does not select
them. Their semantics are not assumed equivalent to the canonical machine.

`MemoryCallMachine.effects` preserves allocation metadata across execution,
including faults and suspension. Contents and initialization require the
function's own contract.

The soundness theorem covers every finite execution prefix, including prefixes
of nonterminating executions. Successful-result theorems are partial correctness
statements. Termination requires a separate argument; a generic decreasing-rank
rule is available in `ControlVerification`. The copy client does not currently
prove termination or a concrete native stack-space bound.

## Proof effort and limits

The buffer versions share a contract and verifier. The standalone
[`BufferExecution.lean`](../lean/Compiler/Baselines/BufferExecution.lean) is a
regression baseline, isolated from active tutorial imports. Source-file line
counts do not measure the transitive size of specifications and library proofs.

The independent copy client uses the same core for three local allocations,
readonly loads, writes, arithmetic, branches and a loop. Its proof adds a client
invariant and two mathematical postcondition lemmas. The optional word automation
library supplies the memory facts. Its explicit `grind` search limits are proof
search settings, not execution fuel or assumptions. More difficult programs may
need additional facts or specialized proof rules proved from the interpreter.

The framework proves execution properties of admitted models. It does not
establish source-to-AIR preservation or native backend correctness. In particular,
modeled allocation exhaustion and monotone allocation history are not a verified
native stack model. Fresh capture and matching object bytes are separate evidence,
not a way to remove these assumptions. See [architecture](architecture.md).

## Checked local bindings

Client invariants can use `MemoryAir.Bindings` to select argument bindings,
allocations, pointer casts and loop labels from generated program data. A list
selection requires a Lean proof that the entry exists. `air_binding%` caches its
normal form with a kernel-checked equality to that selection, avoiding repeated
traversal of the generated code during proof search. `Binding.Saved` bundles a
local's register binding, stored value and, for mutable locals, write capability.
The copy client uses these facilities instead of literal SSA register numbers.
Allocation ordinals do not imply dynamic lifetime IDs: the execution invariant
must still establish those IDs and account for any conditional allocations.

For initialized writable word slices, import `MemorySliceAutomation` and use
`air_slice_finish [yourFacts]` after `air_vcgen`. It normalizes successful
slice selections and typed reads using checked operation equations, preserves
initialization across writes and private allocations, and supplies natural-number
witnesses for bounded integer counter increments. The unchanged
[`std.mem.replaceScalar(u32)` client](../examples/stdlib_replace/README.md)
uses this interface with a client invariant and preservation contract. Its
universal theorem proves safety and framing; it does not assert termination
or the exact replacement list.

## Measuring proof cost

The default verifier uses explicit memory normalization and ordinary VC discharge.
The [shared-context experiment](automation-measurements.md) describes the
alternative tactic and its measurement limits.

Run `zig build benchmark -- --output /tmp/proof-cost` to check the library,
then re-elaborate the buffer, copy and call clients serially, three times each.
The default also includes the independent standard-library replacement client.
Use `--proof path/to/Proofs.lean` (repeatable) and `--repeat N` to select other
clients. Inputs, hashes, process receipts and `report.json` remain outside the
checkout. Lean is pinned to 4.35.0, with two workers and a 4096 MiB process limit.
Every main proof file is checked afresh; imported library modules use their warm
compiled cache. The runner checks the workspace against its build identities
before and after measurement, and rejects changed proof inputs.

The report records elapsed milliseconds and the waited child's maximum resident
set size. This is not a measurement of aggregate concurrent process memory.
Its line count covers the selected file, including comments and imports; it does
not measure the size of transitive specifications or mathematical lemmas.
Compare repeated runs on the same machine with the same dependency-cache state.
These measurements are neither native execution benchmarks nor safety proofs.

[Verification evidence](evidence.md) explains how reports bind their measured
proof snapshots. A report does not establish a general performance bound.
Rerun the benchmark after changing contracts,
models or automation.
