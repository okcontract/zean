# Architecture and trust

Zean captures Zig's analyzed intermediate representation (AIR) after semantic
analysis and before legalization. A Zig decoder checks the selected fragment
and emits program data. Lean checks correspondence and contracts against
interpreters for that data.

## Supported routes

| Profile | AIR admitted | Correspondence certificate |
| --- | --- | --- |
| `scalar` | Selected integer and Boolean operations, casts, structured control | Yes |
| `memory` | Typed pointers, allocation, loads, stores, retained slice guards | Yes |
| `loops` | Memory operations and resumable loops | Yes |
| `aggregate` | Complete aggregate layouts and supported field operations | — |
| `word-bytes` | Restricted, initialized `u32` byte views | — |
| `word-byte-loops` | Word-byte access with resumable loops | — |
| `calls` | Acyclic direct calls with finite bodies | Yes |
| `call-loops` | Looping root with finite callees | Yes |
| `nested-calls` | Acyclic direct calls with looping callees | Yes |
| `recursive-calls` | Checked direct calls, including self and mutual recursion | Yes |

Translation admits ReleaseFast AIR. Memory profiles use the 64-bit,
little-endian AArch64 macOS LLVM target. The dispatch-table example has a
dedicated release/acquire checker. [Admission rules](admission.md) ·
[Dispatch-table example](../examples/atomic_publication/README.md)

## From source to Lean

1. `src/toolchain.zig` archives the pinned Zig release. `src/patch.zig` applies
   the AIR and source-validity hooks in that copy.
2. `SemanticExport.zig` records AIR. `SemanticValidity.zig` records selected
   runtime slice obligations from semantic analysis.
3. `src/capture.zig` inventories the requested roots and compares ordinary
   and instrumented object bytes. Local imports use an explicit source
   closure, and named modules are self-contained leaves.
4. The decoder checks source ownership, types, SSA dominance, body and target
   identities, layouts, and retained guards. It preserves reached work,
   including unused results, failures and earlier effects.
5. Translation emits Lean and its manifest. Directory generation writes
   modules on their import paths. The low-level translator publishes a bundle
   by renaming a new directory after every root passes.

The project command emits correspondence theorems for Lake to check.
Development replay compiles fresh modules in dependency order and audits
the named theorems' transitive axioms. [Native commands](native-tooling.md) ·
[Client workflow](../examples/client/README.md)

## Trust boundaries

A contract holds for the admitted model under its stated assumptions.
Correspondence checks Zig's lowering against an independent Lean decoder.
The source owner, frontend, exporter, and JSON lifting must faithfully
describe the intended program. Source-validity coverage currently includes
selected slice obligations. Target layout, native resource adequacy, and
backend preservation need their own evidence.

Ordinary errors, allocation failure, and reached memory effects remain explicit
in the model. Safety over every finite prefix also applies to prefixes of
nonterminating executions. Proving termination requires a separate progress
argument. Caller contracts state which storage is live, initialized, writable,
or disjoint. Concurrency and foreign boundaries require additional models.
[Verification evidence](evidence.md) · [Open work](architecture-roadmap.md)

## Lean models

| Module or directory | Use |
| --- | --- |
| `Compiler.ZigAir.Verify.Core` | Finite and loop contracts, inline composition, checked bindings, and VC generation |
| `Verify.Words`, `Verify.Slices`, `Verify.Reads`, `Verify.Bytes`, `Verify.Records` | Optional storage views, initialization, byte transport, and field contracts |
| `Verify.Machine` | Explicit call stacks, helper summaries, and branch and loop rules |
| `Verify.Resources`, `Verify.Lifetimes` | Sequential allocation claims, framing, ownership and escape |
| `Compiler.ZigAir.Verify` | Convenience import for the verification domains |
| `Compiler.ZigAir.Control*`, `Machine*` | Structured execution, resumable evaluation, invariants and WP soundness |
| `Compiler.ZigAir.Scalar*`, `Aggregate*`, `Memory*`, `Target` | Value and storage semantics, target geometry, and execution laws |
| `Captured`, `CapturedScalar`, `CapturedCallMachine` | Independent decoding for correspondence certificates |
| `MemoryCall*`, `MemoryPartialCall*` | Earlier finite and partial call interpreters retained for regression |
| `Compiler.Tutorial`, `Compiler.Components` | Example contracts and proof clients |
| `Compiler.Captures`, `Compiler.Cases`, `Compiler.Tests`, `Compiler.Baselines` | Retained models, case studies, controls, and historical baselines |
| `Contract` | Self-contained value semantics and theorem-audit dependencies |

The reusable framework stays independent of captures and tutorial clients.
Core verification and pure initialization facts stay independent of optional
automation. The native test suite checks those import boundaries transitively.

| Development target | Scope |
| --- | --- |
| `zig build lean-core` | Core verifier and dependencies |
| `zig build lean-framework` | Reusable framework, including optional domains and decoders |
| `zig build lean-examples` | Tutorial and component proofs |
| `zig build lean-regressions` | Retained captures, cases, tests, and baselines |
| `zig build lean` | Full `Contract` and `Compiler` libraries and declaration controls |

Run Lean scopes separately with two workers. The full gate also builds modules
that have no importing client. [Proof API](verification.md) ·
[Call machine](call-machine.md) · [Validation](validation.md)
