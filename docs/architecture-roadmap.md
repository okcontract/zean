# Architecture and research priorities

The framework uses deep embeddings, fail-closed admission, independently decoded
AIR certificates and handwritten proof clients. Current interfaces and trust
boundaries are described in [architecture](architecture.md), [admission](admission.md)
and the [call-machine guide](call-machine.md). This document describes open work.

## Source-obligation completeness

The AIR certificate establishes agreement between captured data and the generated
model. It does not prove that capture retained every safety obligation of the
source. Selected runtime slice requirements are recorded during semantic analysis;
other obligations still need explicit coverage.

Every admitted operation needs a precise account of source behavior, captured
types and references, reached effects, independent interpretation, target and
specialization restrictions, and positive/mutation controls. Requirements
reconstructed from AIR must be distinguished from those recorded earlier.
Missing requirements must reject.

Hashes identify artifacts. Matching ordinary and instrumented object bytes checks
exporter noninterference on those compilations. Neither establishes frontend
correctness, native resource adequacy or backend preservation.

## Execution and resources

All production call profiles use function tables and an explicit call stack.
The machine retains continuations through suspension, checks return types and
preserves reached effects on faults. Intraprocedural contracts have an exact
adapter; the Calls and byte-scan contracts are proved against the machine.
Regression interpreters are retained without assuming their equivalence.

The `history` and `reuse` resource policies separate lifetime freshness from
physical storage accounting. Boundary preservation is proved, but whole-execution
resource refinement and native stack adequacy remain open. Safety, fault freedom,
termination and successful completion are separate claims.

The sequential resource interface covers permissions, initialization, ownership
and framing. Aliasing remains a contract condition. Suballocation separation,
fractional permissions and concurrency require further work. Evaluate an
Iris-Lean adapter to the canonical machine, with a proved connection to the
existing safety contracts, before expanding a general resource logic.

## Automation and client coverage

Structural VC rules support instruction sequences, branches, blocks, loops and
checked helper summaries. Unique argument/type/loop selectors reject absent or
ambiguous bindings. Clients still supply loop invariants and mathematical facts;
invariant inference remains open. Checked administrative abstraction and stable
source-local bindings could reduce proof maintenance.

The [shared-context discharge experiment](automation-measurements.md) needs broader
measurements before a default change. Compare elaboration time, memory, proof
maintenance and rejected unsafe mutations while preserving all obligations.

The manifest-driven client workflow binds capture, certification and proof replay
to immutable inputs. Named Zig modules, additional specializations and broader
source closures need explicit admission rules. Target configuration remains
restricted to the documented ABI; unsupported combinations reject.

The [allocator evaluation](../examples/allocator/README.md) certifies reset
correspondence but still rejects five generic-owner paths. Supporting those paths
requires a checked connection between instantiated owner types and source
constructors, followed by allocator-lifetime and container contracts. Matching
only method names or stripping generic arguments would weaken admission.

## Research questions and evaluation

Deep embeddings, weakest preconditions, separation logic, compiler-derived models
and kernel-checked automation are established techniques. A Zig port alone is not
a new research contribution.

The primary question is whether Zig's staged, optimizing frontend can preserve
and expose enough source obligations for compositional verification of unchanged
low-level code. This needs a precise theorem for an explicit fragment and an
evaluation against existing methods.

A second question is whether predictable proof-producing automation can reduce
the annotation and maintenance cost of explicit memory management. The contribution
would be the abstraction or inference method and its evaluation.

Use tutorials as regressions and independently selected components for evaluation.
Record supported/rejected functions, assumptions, source edits, manual proofs,
elaboration and checking costs, repairs after source changes, and mutation
rejections. Distinguish proved modeled bugs, native reachability and unresolved
proofs. A failed proof alone is not a bug witness.

Complete library checks use two Lean workers within 8 GiB aggregate memory.
Toolchain builds, captures and run evidence remain outside the checkout.
Infrastructure improvements do not change source/native assurance flags without
evidence for those claims.

## Bibliography and design consequences

| Reference | Consequence for this project |
| --- | --- |
| Sammler et al., [RefinedC](https://plv.mpi-sws.org/refinedc/paper.pdf), PLDI 2021 | Ownership/refinement contracts and deliberately restricted, predictable foundational proof search. |
| Pulte et al., [CN](https://www.cs.ox.ac.uk/people/christopher.pulte/popl23.pdf), POPL 2023 | Resource inference and maintainable verification of conventional systems software. |
| Gäher et al., [RefinedRust](https://iris-project.org/pdfs/2024-pldi-refinedrust.pdf), PLDI 2024 | Foundational verification of safe and unsafe code; distinguish semantic-model and frontend trust from verified automation. |
| Gäher et al., [Bringing Foundational Verification to Real-World Rust Code](https://iris-project.org/pdfs/2026-oopsla-refinedrust2.pdf), OOPSLA 2026 | Richer abstraction support and an ACE memory-subsystem case study, including its allocator, provide a realistic evaluation reference. |
| Greenaway et al., [AutoCorres](https://trustworthy.systems/projects/OLD/autocorres), ITP 2012 and PLDI 2014 | Generate higher-level abstractions with correspondence proofs to simplify clients without changing the reference semantics. |
| Ho and Protzenko, [Aeneas](https://arxiv.org/abs/2206.07185), ICFP 2022 | Ownership can remove explicit memory reasoning for suitable fragments; Zig needs justified contracts rather than assumed Rust guarantees. |
| Memarian et al., [Cerberus and pointer provenance](https://www.cl.cam.ac.uk/~pes20/cerberus/), PLDI 2016 and POPL 2019 | Specify lifetime, provenance, representation and compiler assumptions, not just bounds. |
| [CompCert](https://compcert.org/man/manual001.html) and [Verified Software Toolchain](https://vst.cs.princeton.edu/) | Connect program-logic soundness, operational semantics and compiler preservation through explicit interfaces. |
| Lopes et al., [Alive2](https://web.ist.utl.pt/nuno.lopes/pubs/alive2-pldi21.pdf), PLDI 2021 | Translation validation must account for undefined behavior and state its bounds. |
| Xia et al., [Interaction Trees](https://arxiv.org/abs/1906.00046), POPL 2020 | Compositional effects and nontermination inform execution adequacy and call semantics. |
| Lattuada et al., [Verus](https://arxiv.org/abs/2303.05491), OOPSLA 2023; Hance et al., [VerusBelt](https://iris-project.org/pdfs/2026-pldi-verusbelt.pdf), PLDI 2026 | Practical automation and semantic foundations require separate evaluation and justification. |
| O'Hearn, [Incorrectness Logic](https://popl20.sigplan.org/details/POPL-2020-Research-Papers/22/Incorrectness-Logic), POPL 2020 | A failed safety proof is distinct from a proved reachable error. |
| de Medeiros et al., [Iris in Lean](https://arxiv.org/abs/2609.24252), September 2026 preprint; [Lean 4.35.0 implementation](https://github.com/leanprover-community/iris-lean/releases/tag/v4.35.0) | Evaluate existing resource and proof-mode infrastructure before implementing another ownership framework. |
| [Lean 4.35.0 release](https://lean-lang.org/doc/reference/latest/releases/v4.35.0/) | Deep-language WP support and shared-context VC discharge are available on the pinned toolchain. |

Related work in development includes [lean-miri](https://github.com/proofs-rs/lean-miri),
which imports Rust MIR into a shared Lean interpreter for safety proofs, and the
[Semantics Done Quick](https://oath.tech/pub/2026/05/semantics-done-quick/) proposal
for Zig `comptime` semantics. The latter is a research proposal, not evidence of
a completed verifier. These projects further limit broad novelty claims about
translating compiler IR into Lean.
