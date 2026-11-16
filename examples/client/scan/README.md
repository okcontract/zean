# Verify a byte scan with branches, a loop, and a helper

This example checks a small Zig loop through the generic call-stack verifier.
It reads a caller-supplied byte range, calls a helper for each reached byte,
and returns early when it finds zero. The proof supplies a storage contract
and a loop invariant. The library generates the instruction, branch, call,
and back-edge obligations from the captured program.

```zig
noinline fn nonzero(value: u8) bool {
    return value != 0;
}

export fn all_nonzero(bytes: [*]const u8, length: usize) bool {
    var index: usize = 0;
    while (index < length) : (index += 1) {
        if (!nonzero(bytes[index])) return false;
    }
    return true;
}
```

`noinline` retains the runtime call, so the proof must compose with a checked
helper contract. Both functions remain executable data in the generated table.

## Capture and verify

From the repository root, using an instrumented Zig 0.17.1
[toolchain report](../../../docs/toolchain.md):

```sh
zig build verify-client -- \
  --manifest examples/client/scan/client.json \
  --toolchain /path/to/toolchain/report.json \
  --output /tmp/byte-scan-verification
```

Use a new output directory for each run. The command captures [scan.zig](scan.zig),
compares ordinary and instrumented native objects, translates the call closure,
checks the independent AIR decoding certificate, and replays
[Proofs.lean](Proofs.lean). It audits the named theorem's dependencies and retains
the generated module, process receipts, and evidence report outside the checkout.

The [manifest](client.json) selects `call-loops` admission and `call-machine`
execution. No example name or instruction number is registered in the verifier.

## Contract and invariant

The caller supplies valid modeled memory, a length that fits `usize`, and
initialized readable bytes throughout the requested range. Memory outside
that range is arbitrary. The proof allows an empty range, which performs no
byte access.

The helper theorem establishes the exact Boolean result of comparing an
arbitrary byte with zero and proves that its memory state is unchanged.
The caller uses a checked summary of that theorem, with the helper body opaque.

The loop invariant states that the index is between zero and the requested
length, that the saved pointer and length are still available, and that the
caller memory is preserved. Only the function's stack locals may have changed.
Selectors obtain the relevant bindings from the generated program by argument
position or type. Selection rejects missing or ambiguous matches; it does not
silently pick an instruction number.

The proof follows this pattern:

```lean
Triple (verify functions root arguments invariants) precondition postcondition errors
```

`verify` denotes the same actual invocation as `invoke`. The invariant argument
selects a proof rule; it does not change execution. `machine_vcgen` generates
the obligations, `machine_normalize` exposes the client assertions, and the
existing byte-memory tactics discharge routine memory and arithmetic facts.
Loop entry must establish the invariant, and each back edge must preserve it.
Branches keep their path conditions, including the path that returns early.

## What is proved

`safe` excludes modeled memory, initialization, typing, and arithmetic faults
from every finite execution prefix. Out-of-memory remains an allowed outcome.
The stronger `checked` theorem also preserves the caller heap and heap validity
on success and permitted failure, and checks the successful result's Boolean
type. The theorem does not yet characterize the scan's Boolean result for the
entire range or prove termination. Those are additional correctness obligations
that can use the same postcondition interface.

This is nearly automatic verification once the storage contract, helper
summary, and invariant are supplied. The framework does not infer those
assertions. Unsupported constructs reject, and unresolved Lean goals are
failed verification obligations. The checked result concerns the modeled
execution; source-obligation completeness and native compiler preservation
remain separate assurance boundaries.

## Exercise the boundary

[overrun.zig](overrun.zig) changes the loop test from `index < length` to
`index <= length`. Replay the unchanged proof with the
[overrun-proof.json](overrun-proof.json) manifest into a new output directory:

```sh
zig build verify-client -- \
  --manifest examples/client/scan/overrun-proof.json \
  --toolchain /path/to/toolchain/report.json \
  --output /tmp/byte-scan-rejected-proof
```

The command must fail at the proof stage. A range containing no zero now
reaches a read at index `length`, which the original caller contract cannot
justify. Strengthening the invariant cannot make that read safe under the same
contract; the program or its real caller requirements must change.

A failed proof alone does not establish a defect. The separate
[OverrunWitness.lean](OverrunWitness.lean) proof supplies a valid initialized
one-byte input, checks the actual interpreter execution by kernel reduction,
and derives `¬Safe`. One iteration and a helper call complete before the
one-past-the-end read faults; cleanup preserves the caller allocation.

```sh
zig build verify-client -- \
  --manifest examples/client/scan/overrun.json \
  --toolchain /path/to/toolchain/report.json \
  --output /tmp/byte-scan-counterexample
```

This command should succeed: it proves the counterexample, using a fresh
capture of the broken program. The input is chosen manually, and the result
is a modeled defect in this deliberate control. Library controls additionally
exercise nested loops, malformed
branch/jump/repeat targets, and a helper fault after a loop back edge.
