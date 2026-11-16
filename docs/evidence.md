# Verification evidence

Checked-in generated modules record the source, AIR, and capture identities
available for their program data. Those hashes identify inputs; they do not
authenticate the producer or establish native compiler correctness.

The portable examples build from files included in this repository. Their
native tests check source/model bindings, and Lean checks the supplied program
definitions, contracts, correspondence certificates where present, and fault
controls. A current successful build does not refresh a retained capture.

To produce fresh evidence, build the instrumented compiler using the public
pinned release described in [the toolchain guide](toolchain.md), then run the
relevant `*-regenerate -- ... --check` target or a manifest-based
[`verify-client`](../examples/client/README.md) workflow. The
[validation guide](validation.md) describes the complete release gate.

Fresh outputs retain source snapshots, captured AIR, ordinary/instrumented object
comparisons, generated models, proof inputs, checked theorem dependencies,
diagnostics, and process receipts. The report binds each result to those exact
inputs. Reusing a report after changing an input does not verify the new input.

Model proofs establish their stated contracts in the selected interpreter.
Source validity, capture completeness, target ABI adequacy, native resource
correspondence, and backend preservation require their own evidence. See
[architecture and trust](architecture.md).
