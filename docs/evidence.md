# Verification evidence

Read each result against the inputs it names.

| Check | What it establishes |
| --- | --- |
| Retained-model build | Lean accepts the checked-in definitions, proofs, and any correspondence certificates they contain. |
| Fresh native capture | The requested AIR roots were captured from the recorded sources and toolchain. Ordinary and instrumented objects matched for those compilations. |
| AIR correspondence | Lean's independent interpretation of the captured data agrees with the emitted model. |
| Proof replay | The named theorems hold for that model and their stated assumptions. The report records the proof inputs and axiom checks. |

`zean --check` compares fresh models with the generated files. Check their
correspondence theorems and handwritten proofs with Lake. To retain capture
and proof receipts from one run, use `verify-client` or an example's
`*-regenerate` target. [Client guide](../examples/client/README.md) ·
[Release gate](validation.md#fresh-capture-release-gate)

Evidence directories retain inputs, hashes, generated data, diagnostics and
process receipts. Hashes identify bytes. Producer authentication, full
source-validity coverage, ABI adequacy, native resources, and backend
preservation need separate evidence. [Trust boundaries](architecture.md)
