# Research priorities

These are open questions about the decoder, interpreters, and proof tools.
[Architecture](architecture.md) · [Admission](admission.md)

## Source obligations

The exporter records selected runtime slice requirements during semantic
analysis. Extend that coverage to obligations optimization can erase.
For each supported operation, specify source behavior, captured identities,
reached effects, target and specialization limits, and rejection controls.
Mark which facts were recorded before optimization and which were reconstructed
from AIR. Reject missing requirements. Prove a source-to-model result for an
explicit fragment.

## Execution and resources

The call machine preserves continuations, lifetimes, and reached effects.
Its `.history` and `.reuse` policies distinguish fresh lifetime IDs from
physical storage accounting. Boundary preservation is checked. Prove the
whole-execution relationship and justify a native stack bound.
[Call-machine rules](call-machine.md)

Extend the sequential allocation claims to suballocation, fractional
permissions, and concurrency. Evaluate an Iris-Lean adapter with a proof
connecting it to the existing machine safety contracts.
[Ownership models](lifetimes.md)

## Automation and coverage

Clients supply invariants and mathematical facts. Stable source-local
bindings and checked abstractions could reduce maintenance after
recompilation. Compare shared-context and ordinary VC discharge on proof
size, time, memory, repairs, and unsafe mutations.
[Measurement protocol](automation-measurements.md)

Extend client support for named Zig modules and additional specializations
with explicit admission rules. The allocator evaluation certified
`client.reset` and rejected five generic-owner paths. Those paths need a
checked link from instantiated types to source constructors, then allocator
lifetime and container contracts. [Allocator results](../examples/allocator/README.md)

## Evaluation

Use tutorials as regression tests and independently chosen components for
evaluation. Record admission outcomes, assumptions, source edits, manual
proof work, and proof-checking costs. Distinguish a checked model
counterexample, a native execution witness, and an unresolved proof.
Keep toolchain builds, captures, and reports outside the checkout.
[Evidence scope](evidence.md)

## References

| Reference | What to compare or reuse |
| --- | --- |
| Sammler et al., PLDI 2021 | Ownership and refinement contracts with predictable foundational search. [RefinedC](https://plv.mpi-sws.org/refinedc/paper.pdf) |
| Pulte et al., POPL 2023 | Resource inference and maintainable systems proofs. [CN](https://www.cs.ox.ac.uk/people/christopher.pulte/popl23.pdf) |
| Gäher et al., PLDI 2024 and OOPSLA 2026 | Frontend trust, abstraction support, and the ACE allocator case study. [RefinedRust](https://iris-project.org/pdfs/2024-pldi-refinedrust.pdf) · [ACE verification](https://iris-project.org/pdfs/2026-oopsla-refinedrust2.pdf) |
| Greenaway et al., ITP 2012 and PLDI 2014 | Higher-level abstractions backed by correspondence proofs. [AutoCorres](https://trustworthy.systems/projects/OLD/autocorres) |
| Ho and Protzenko, ICFP 2022 | How ownership assumptions can simplify memory reasoning. [Aeneas](https://arxiv.org/abs/2206.07185) |
| Memarian et al., PLDI 2016 and POPL 2019 | Lifetime, pointer provenance, and representation. [Cerberus](https://www.cl.cam.ac.uk/~pes20/cerberus/) |
| Compiler verification | Interfaces between program logic, operational semantics, and native code. [CompCert](https://compcert.org/man/manual001.html) · [VST](https://vst.cs.princeton.edu/) |
| Lopes et al., PLDI 2021 | Translation validation and undefined behavior. [Alive2](https://web.ist.utl.pt/nuno.lopes/pubs/alive2-pldi21.pdf) |
| Xia et al., POPL 2020 | Compositional effects and nontermination. [Interaction Trees](https://arxiv.org/abs/1906.00046) |
| Lattuada et al., OOPSLA 2023 and Hance et al., PLDI 2026 | Performance of automation and justification of semantics. [Verus](https://arxiv.org/abs/2303.05491) · [VerusBelt](https://iris-project.org/pdfs/2026-pldi-verusbelt.pdf) |
| O'Hearn, POPL 2020 | Proofs of reachable errors. [Incorrectness Logic](https://popl20.sigplan.org/details/POPL-2020-Research-Papers/22/Incorrectness-Logic) |
| de Medeiros et al., September 2026 preprint | Resource and proof-mode infrastructure for Lean 4.35.0. [Iris in Lean](https://arxiv.org/abs/2609.24252) · [Implementation](https://github.com/leanprover-community/iris-lean/releases/tag/v4.35.0) |
| Lean 4.35.0 | Deep-language WP and shared-context VC discharge. [Release notes](https://lean-lang.org/doc/reference/latest/releases/v4.35.0/) |

Related projects import Rust MIR into Lean or propose semantics for Zig
`comptime`. [lean-miri](https://github.com/proofs-rs/lean-miri) ·
[Semantics Done Quick proposal](https://oath.tech/pub/2026/05/semantics-done-quick/)
