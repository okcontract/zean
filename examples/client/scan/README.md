# Verify a byte scan

`all_nonzero` scans a caller-supplied byte range. It calls `nonzero` on each
reached byte and returns early on zero. The `call-loops` profile keeps
the runtime helper in the generated table. [Zig source](scan.zig) ·
[Client manifest](client.json)

```sh
zig build verify-client -- \
  --manifest examples/client/scan/client.json \
  --toolchain /path/to/toolchain/report.json \
  --output /tmp/byte-scan-verification
```

The caller supplies live initialized bytes for the requested range and a
length that fits `usize`. An empty range is valid. The helper contract
proves the exact comparison result and preserves memory.

The loop invariant tracks `0 ≤ index ≤ length`, the saved pointer and
length, and preservation of caller memory. Checked selectors find the
saved bindings. `machine_vcgen` generates the branch, call, and back-edge
obligations. `machine_normalize` and the byte tactics prepare the memory
goals. The caller uses the helper contract with its body opaque.
[Proof and invariant](Proofs.lean) · [Call-machine guide](../../../docs/call-machine.md)

`safe` excludes memory, initialization, typing, and arithmetic faults
for every finite prefix. `checked` also preserves the heap on success and
modeled exhaustion and gives the Boolean result type. The scan's full
Boolean specification and termination are separate obligations.

## Check the one-past-end error

Changing `index < length` to `index <= length` allows a read at `length`
after an all-nonzero range. The original proof fails on that read.
[Changed source](overrun.zig)

```sh
zig build verify-client -- \
  --manifest examples/client/scan/overrun-proof.json \
  --toolchain /path/to/toolchain/report.json \
  --output /tmp/byte-scan-rejected-proof
```

The witness below succeeds. Lean checks a valid one-byte input that
completes one iteration and helper call, faults on the next read, and
preserves the caller allocation during cleanup.
[Counterexample proof](OverrunWitness.lean)

```sh
zig build verify-client -- \
  --manifest examples/client/scan/overrun.json \
  --toolchain /path/to/toolchain/report.json \
  --output /tmp/byte-scan-counterexample
```

Use a fresh output directory for each replay. The reports bind the proof
results to the captured AIR and check native object equality.
[Toolchain setup](../../../docs/toolchain.md) · [Evidence scope](../../../docs/evidence.md)
