# Verify a caller with a helper contract

`update` calls a `noinline` helper that writes one `u32`. The `calls` profile
keeps both bodies in the generated function table.
[Zig source](cell.zig) · [Client manifest](client.json)

```sh
zig build verify-client -- \
  --manifest examples/client/calls/client.json \
  --toolchain /path/to/toolchain/report.json \
  --output /tmp/cell-calls-verification
```

Replay captures both functions, checks correspondence, and audits the
safety theorem against the fresh model. Use a new evidence directory for
each run. [Toolchain setup](../../../docs/toolchain.md)

The caller supplies a valid heap and a writable region of at least one word.
The word may start uninitialized. `put_checked` verifies the helper with
`machine_vcgen`. `update_checked` uses the resulting `putContract` with
the helper body opaque. `safe` excludes memory, initialization, type, and
arithmetic faults in every finite prefix. Modeled exhaustion is allowed.
Termination and the exact written value are separate contracts.
[Handwritten proof](Proofs.lean) · [Call-machine guide](../../../docs/call-machine.md)

## Write the neighboring word

The changed helper writes `words[1]`. The original contract allows a
one-word region, so the original safety proof fails. A separate witness
uses such a region and proves that the model reaches `.memoryValidity`.
[Changed source](neighbor.zig) · [Witness](NeighborWitness.lean)

```sh
zig build verify-client -- \
  --manifest examples/client/calls/neighbor.json \
  --toolchain /path/to/toolchain/report.json \
  --output /tmp/cell-neighbor-witness
```

The witness command succeeds when Lean proves the modeled fault.
[Evidence scope](../../../docs/evidence.md)
