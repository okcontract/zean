# Verify a caller using a checked helper contract

This example proves memory safety for two small Zig functions using the explicit
call-stack interpreter. The generic library derives the instruction obligations;
the proof supplies the caller's storage contract and a checked summary for the
helper. It contains no AIR instruction numbers or executable substitute for the
helper.

The [Zig program](cell.zig) writes a word through a pointer:

```zig
noinline fn put(pointer: *u32, value: u32) void {
    pointer.* = value;
}

export fn update(pointer: *u32, value: u32) void {
    put(pointer, value);
}
```

`noinline` keeps a runtime call in the captured program. Both functions remain
executable data in the generated Lean table. The generated source names their
indices `FunctionId.fn_put` and `FunctionId.fn_update`, lays out sequential
instructions using `<|`, and places capture records after the program data.
The independent decoder checks that this table represents the admitted AIR.

## Capture, translate and check

With an instrumented Zig 0.17.1 [toolchain report](../../../docs/toolchain.md),
run from the repository root:

```sh
zig build verify-client -- \
  --manifest examples/client/calls/client.json \
  --toolchain /path/to/toolchain/report.json \
  --output /tmp/cell-calls-verification
```

Choose a new output directory each time. The command captures the source,
compares ordinary and instrumented native objects, translates both functions,
checks AIR correspondence, replays [Proofs.lean](Proofs.lean) against the fresh
module, and audits the named safety theorem's dependencies. Generated files,
capture data and process evidence stay in that output directory.

The [manifest](client.json) selects `calls` admission and
`"executionModel": "call-machine"`. Its imports name only the generated module
and generic verification libraries. A different supported client can use this
workflow without adding a tutorial command or changing the verifier.

## What the proof establishes

The contract requires a valid memory state and a writable logical word region
with at least one element. The initial word may be uninitialized: this program
writes it before any read. The inputs, allocation identities and surrounding
memory are arbitrary.

`put_checked` unfolds the generated helper and uses `machine_vcgen` with the
existing word-memory rules. `putContract` packages its successful result and
fault conditions. `update_checked` then verifies the caller using that summary;
the helper definition is made opaque during this proof. This checks that the
summary suffices without unfolding the helper body again.

`safe` excludes modeled memory, initialization, typing and arithmetic faults
from every finite execution prefix. Out-of-memory remains a permitted outcome.
Heap validity is also preserved on success, but heap validity alone would not
establish memory safety. The theorem does not assert termination, the exact
written value, or native resource adequacy. Stronger result and memory
postconditions can be supplied through the same `Std.WP` interface.

## Change the program and replay

A useful negative experiment changes the helper to write the neighboring word:

```zig
noinline fn put(pointer: *u32, value: u32) void {
    const words: [*]u32 = @ptrCast(pointer);
    words[1] = value;
}
```

Keep the original proof and replay into a new directory. The source can still
be admitted and its AIR certified, but the old contract permits a one-word
region. It cannot establish safety for the new write. Restore the original
write or supply a stronger contract justified by real callers. A failed proof
alone is not a reachable native bug witness.

The checked counterexample uses [neighbor.zig](neighbor.zig) and
[NeighborWitness.lean](NeighborWitness.lean). It supplies a valid one-word
caller satisfying the original contract, proves that execution reaches
`.memoryValidity`, and derives the negation of modeled memory safety:

```sh
zig build verify-client -- \
  --manifest examples/client/calls/neighbor.json \
  --toolchain /path/to/toolchain/report.json \
  --output /tmp/cell-neighbor-witness
```

This command should succeed: its obligations prove the counterexample. The
finite execution is reduced by Lean's kernel. Choosing the input is manual;
the example does not claim automatic bug discovery or native reachability.

For this small program, routine memory obligations are discharged by the
generic tactics once the contracts are supplied. This is not automatic memory
safety for arbitrary Zig. Unsupported source and AIR still reject; the
call-machine automation also supports branches, blocks and loops with supplied
invariants. The [byte-scanning client](../scan/README.md) demonstrates those
rules with a helper call inside the loop; see the
[call-machine guide](../../../docs/call-machine.md) for the soundness boundary.

The final report keeps model proofs, native object comparison, source safety
and compiler preservation separate. These proofs cover modeled execution under
the stated contract. They do not prove that all Zig callers satisfy it or that
the compiler preserves all source behavior.
