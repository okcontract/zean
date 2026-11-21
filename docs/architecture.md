# Architecture and trust

Zean captures AIR and validates its source declarations with native Zig
tools. It rejects constructs outside the declared admission boundaries.

The [research priorities](architecture-roadmap.md) describe open assurance and
coverage work, evaluation criteria and relevant literature.

## Supported routes

| Route | Support and evidence |
| --- | --- |
| Scalar AIR | Zig 0.17.1 native counter captures and exact execution/safety proofs, including the `u32` example |
| Memory, loops, aggregates and word-byte AIR | Restricted typed models; all six decoders have output/rejection controls and emitted Lean compilation checks; the buffer tutorial adds native captures with universal safety, update and preservation proofs |
| Direct-call AIR | Call profiles support acyclic closures, looping callees and opt-in recursive direct calls; declarations and owners are checked throughout the closure and independent Lean decoders check AIR correspondence |
| Native memory and slice export | Debug and ReleaseFast fixture audits with ordinary/instrumented/bootstrap object comparison; the memory oracle requires AArch64/macOS |
| Source ownership and specialization | AST-selected declarations, explicit captured source closures, checked type arguments and runtime parameter mappings |
| Standard-library replacement and word swap | Restricted captured specializations with explicit initialization, permission and aliasing contracts |

The [validation guide](validation.md) distinguishes fixture tests, model proofs
and fresh native capture evidence. Recorded capture identities are preserved.
Current entry points are documented in [native tooling](native-tooling.md).

## AIR route

```text
Zig 0.17.1 source + explicit dependencies
    → isolated, pinned instrumented compiler
    → bounded capture report + typed AIR + source/tool identities
    → native Zig decoder and profile checks
    → Generated.lean + identity/scope reports
    → Lean interpreters and proof clients
```

`src/toolchain.zig` archives the clean release and builds the isolated LLVM
compiler. `src/patch.zig` applies the reviewed hooks.
`lean/zig_air/SemanticExport.zig` observes AIR after semantic analysis and before
legalization; `SemanticValidity.zig` records selected runtime slice obligations.

`src/capture.zig` compiles with and without capture, compares object bytes and
inventories all requested roots. Local imports require explicit source files;
named modules must be self-contained leaves. Source/tool identities are checked
again before successful completion. Import inventory does not establish full
semantic dependency coverage.

The decoders check signatures, types, SSA dominance, structured body ownership,
block targets, loop ownership, source guards and profile restrictions. Reached
dead-result operations and faults stay in the program. Specialized word-swap
lowering has an explicit additional initialization and aliasing contract.
`zig build admission` publishes the versioned operation and obligation inventory;
inventory membership is an additional gate, not complete source-validity coverage.

The [generic client workflow](../examples/client/README.md) binds a declarative
source closure, capture, certified translation and separately supplied proof
modules. Replay uses fresh module names and audits the named client theorems'
transitive axioms. It checks the supplied propositions without deciding whether
their contracts are strong enough for an application.

The standalone translator binds the exact parsed bytes to their manifest
hashes and emits one declaration per requested root. Publication is a single
rename into a new directory after every root passes. Hashes identify supplied
bytes; they do not authenticate the producer. `nativeCaptureVerified` and
source/backend correctness claims stay false. Synthetic input classification
is retained when supplied.

## Source ownership

`src/source.zig` uses `std.zig.Tokenizer` and `std.zig.Ast` for source inspection.
`src/declaration_source.zig` selects ordinary functions in their actual file and
container owners. `src/specialized_source.zig` checks explicit type arguments and
runtime parameter mappings. An unrelated declaration with the same final name
cannot replace the selected owner. Calls bind complete captured identities and
source hashes throughout the admitted closure.

Source identification, parsing, type admission, primitive contracts and
specialization remain trusted boundaries. These checks identify supplied bytes;
they do not establish source-to-AIR preservation. Record operations require
complete captured layouts, declared fields, checked extents and permissions.
Unsupported targets, partial layouts, padding accesses and enum operations reject.

## Lean models

| Location or entry point | Role |
| --- | --- |
| `Compiler.ZigAir.Verify.Core` | Finite/loop contracts, inline composition, local bindings and generic instruction automation |
| `Verify.Words`, `Verify.Slices`, `Verify.Reads`, `Verify.Bytes`, `Verify.Records` | Optional word-buffer facts, writable slices, initialized readonly views, byte-copy contracts and complete record fields |
| `Compiler.ZigAir.Verify.Lifetimes` | Separate allocator ownership/escape models |
| `Compiler.ZigAir.Verify.Machine` | Canonical data-based call machine, checked call summaries, branch/loop VC generation, finite reachability and exact transfer of intraprocedural contracts |
| `Compiler.ZigAir.Verify.Resources` | Sequential allocation claims, effect framing, ownership contracts and explicit storage reclamation |
| `Compiler.ZigAir.Verify` | Convenience import for all verification domains |
| `Compiler.ZigAir.Control*`, `Machine*` | Structured execution, resumable machines, invariants and interpreter-backed WP soundness |
| `Compiler.ZigAir.Scalar*`, `Aggregate*`, `Memory*` | Reusable value, storage and execution semantics and their proofs |
| `MemoryVerification`, `MemoryPrimitiveWP`, `MemoryAutomation` | Invocation contracts, primitive specifications and proof-producing VC generation |
| `MemoryCall*` (excluding `MemoryCallMachine*`) | Regression finite-call execution, callee specifications, WP soundness and call automation |
| `MemoryPartialCall*` | Regression stable finite observations of acyclic looping call chains, WP soundness and callee-contract automation |
| `MemoryCallMachine*`, `CapturedCallMachine` | Explicit call stacks, checked function-table decoding and the intraprocedural interpreter adapter |
| `MemoryCallMachineVC*`, `MemoryCallMachineAutomation` | Structural obligations, their soundness for the canonical interpreter, and `Std.WP` rules for blocks, branches, loops and calls |
| `MemoryClaims`, `MemoryClaimWP`, `MemoryReclaim` | Allocation-granular separating claims, frames on successful and exceptional exits, and reuse without recycling lifetime IDs |
| `Target` | Independent interpretation of the validated target configuration and checked memory-geometry agreements |
| `MemoryResources`, `MemoryTotalVerification` | Explicit modeled resource bounds and successful-completion obligations |
| `MemoryFrameVerification`, `MemoryRootCapability` | Stack/caller framing and writable root capabilities |
| `MemoryWordFrameVerification`, `MemoryBorrowedWords` | Optional word views, copied prefixes and caller-memory preservation |
| `MemorySliceLaws`, `MemoryInitializedWords` | Pure slice evaluation and initialization facts, independent of WP |
| `MemoryReadView`, `MemoryReadAutomation` | Readonly extent and contents laws, with optional VC automation |
| `Compiler.ZigAir.Captured` | Captured-program interpretation and the checked decoding relation used by correspondence certificates |
| `Compiler.Tutorial`, `Compiler.Components` | Example contracts and proof clients, including standard-library replacement |
| `Compiler.Captures` | Retained generated AIR program data; [producer notes](../lean/Compiler/Captures/README.md) |
| `Compiler.Cases` | Concrete scalar, exponentiation, fill, word-swap and memory developments |
| `Compiler.Tests`, `Compiler.Baselines` | Kernel-checked controls/audits and the historical buffer execution baseline |
| `Contract` | Self-contained value semantics and theorem-audit dependencies |

The reusable `ZigAir` library imports no captures, case studies, tutorial clients
or regression modules. `Verify.Core` does not import optional call, word-buffer
or slice automation. Pure initialization facts do not import WP rules.
`zig build test` checks these import boundaries transitively, verifies that
local imports exist, and rejects tutorial dependencies on historical baselines.

Use the narrowest development check that covers a change:

| Command | Scope |
| --- | --- |
| `zig build lean-core` | Core verification API and its dependencies |
| `zig build lean-framework` | Every reusable framework module, including optional domains and certificates |
| `zig build lean-examples` | Tutorial and component proofs |
| `zig build lean-regressions` | Retained captures, standard-library cases, tests and baselines |
| `zig build lean` | Complete `Contract` and `Compiler` libraries plus admission controls |

Each scope uses two Lean workers. Run scopes separately to keep aggregate
verification within the 8 GiB budget. Scope enumeration includes modules that
have no importing clients. The full `lean`, `check` and `release-check` targets
retain Lake's recursive module globs, so focused development checks do not
remove release coverage. Fresh example replay builds its selected import set;
the release gate still checks the full library before capture and replay.

Namespaces and historical generated definitions are preserved. A successful
Lean build establishes acceptance of those models and proofs by Lean 4.35.0.
Native source correspondence, ABI adequacy, allocator behavior, frontend and
backend preservation require their own contracts and evidence. Source-validity
coverage remains incomplete. Several memory profiles are specifically tied to
64-bit, little-endian AArch64/macOS LLVM builds.

Keep ordinary errors, allocation failure, unsupported observations and resource
exhaustion explicit. Test/reference data and historical captures do not establish
coverage of all functions or all Zig constructs.

The structured verification rules consume arbitrary admitted control trees.
Clients supply contracts and loop-header invariants; the library propagates
obligations through instructions, branches, blocks and back edges. The soundness
theorem connects these obligations to every finite prefix of the existing
resumable machine, including nonterminating executions. Fault postconditions
are separate from heap validity and successful results. Termination requires a
separate decreasing rank. `zig build wp-proofs` checks these rules and controls
for reached faults, prior effects, block environments and looping behavior.

Logical invariant checkpoints occur during verification, not in the native
program. A checked model contract retains the source/compiler boundaries above.
Inline fragments have independently checked contracts composable with arbitrary
continuations. The optional call layer separately supports admitted direct-call
closures through the `calls`, `call-loops` and `nested-calls` profiles; callers can reuse callee
contracts without unfolding their bodies. Unsupported call patterns still
reject. The sequential frame predicates permit aliases and do not impose
exclusive ownership or a concurrency discipline.
See the [verification guide](verification.md) for the client API and proof-effort
comparison.

The default [call-machine route](call-machine.md) retains caller continuations as
data and proves exact resumption. Its intraprocedural adapter transfers existing
contracts, and its structural VC rules support branches, loops and checked helper
summaries. The independent [byte-scan client](../examples/client/scan/README.md)
supplies the loop invariant and storage contract; generic rules prove safety
without unfolding the helper. The buffer contract transfers through the exact
intraprocedural adapter. The earlier interpreters are retained for regression checks. The machine's
optional reuse policy preserves live accesses and lifetime freshness at cleanup boundaries,
but has no claimed native stack-capacity adequacy theorem.

The [sequential resource interface](../lean/Compiler/ZigAir/MemoryClaims.lean)
provides allocation claims and framing; its
[WP rule](../lean/Compiler/ZigAir/MemoryClaimWP.lean) preserves disjoint claims on
both successful and exceptional exits.
The [allocator-backed benchmark](../examples/allocator/README.md) records an
independent component inventory and current admission failures, keeping rejected
constructs distinct from safety proofs and bug witnesses.

The [buffer tutorial](../examples/buffer/README.md) proves a checked replacement
safe for every valid caller heap, writable `u32` view, 64-bit index and 32-bit
value. It derives pointer and store success from the storage contract, preserves
surrounding memory, and relates initialized contents to a list update. It accounts
for the captured pointer's stack slot and modeled exhaustion. An off-by-one
capture has both an allocation-boundary fault and a logical-buffer escape within
a larger allocation. These are model theorems with explicit caller, target and
source/compiler assumptions, not general Zig memory-safety guarantees.

The independent [copy tutorial](../examples/copy/README.md) uses the same verifier
for a loop with three stack slots and an inline helper. It proves safety over all
execution prefixes and copy/source/frame guarantees on completion. Its invariant
and postcondition facts are client code. Initialization, pointer access, stores,
local-slot preservation and control-flow reasoning are generic library rules.
It does not establish termination or a native stack-space bound.
