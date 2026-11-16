# Ownership and lifetime contracts

`Compiler.ZigAir.Verify.Lifetimes` provides optional, sequential contracts for
allocator ownership, replacing a byte allocation, and pointers that escape a
function. These contracts extend the memory model. They do **not** currently
admit native allocator vtables, `realloc`, or macOS FFI calls through the AIR
translator.

Check the library and its controls through the public build interface:

```sh
zig build lean-module -Dlean-module=Compiler.Tests.ZigAir.MemoryOwnershipControls
zig build lean-module -Dlean-module=Compiler.Tests.ZigAir.MemoryEscapeControls
```

## Ownership is part of the state

[`MemoryOwnership.lean`](../lean/Compiler/ZigAir/MemoryOwnership.lean) pairs a
modeled heap with a registry mapping allocation lifetimes to allocator identities.
A pointer alone cannot authorize release. `World.Consistent` requires distinct
registry entries backed by live, writable, persistent allocations.

Release checks the allocator identity, zero offset, complete declared type,
write permission and persistent lifetime. Successful release removes the
allocation and consumes its registry entry. The checked rules establish that:

- Every alias carrying that lifetime becomes unallocated, regardless of offset.
- A second release rejects.
- Reads and ownership entries for other allocations remain unchanged.
- Allocation counters do not rewind. Reusing a physical base creates a fresh
  lifetime; it does not revive an old pointer.

This is an explicit sequential ownership discipline. It does not infer exclusive
borrows, prevent concurrent races, or establish the origin of an external
pointer. A client introducing a heap and registry must justify their relationship
to the actual caller state.

## Replacing an allocation

[`replaceBytes`](../lean/Compiler/ZigAir/MemoryOwnedReplacement.lean) models an
explicit allocate, copy, release protocol. It validates the old owner before
requesting a new region. The allocator receives the complete size and alignment;
its private effects survive every response. Returned regions are checked for
alignment, extent and separation before publication.

Ordinary allocation failure retains the old allocation and owner. On success,
the protocol copies the shorter extent and then releases the old allocation.
A reached copying fault retains the actual completed prefix and both allocations.
It is a verification failure, not an invented rollback. Empty allocations create
no releasable ownership entry.

The quantified
[`replaceBytes_success`](../lean/Compiler/ZigAir/MemoryOwnedReplacementContracts.lean)
theorem assumes a consistent old allocation, initialized source bytes, a nonempty
replacement and a returned region satisfying the checked geometry contract.
It proves the copied prefix in the new allocation, its write capability, the new
ownership entry, and retirement of the old lifetime. The new tail does not acquire
an initialization guarantee. These are sufficient caller assumptions, not a
claim that every legal native replacement requires them.

The protocol is separate from Zig's allocator ABI. Connecting a native allocator
requires capturing and admitting the relevant implementation, or stating an
explicit external contract whose native justification is independently reviewed.
The translator does not silently replace an unsupported allocator call with this
model.

## Escaping pointers

[`MemoryEscape.lean`](../lean/Compiler/ZigAir/MemoryEscape.lean) follows lifetime
identities through returned values, optional record fields and pointers stored in
reachable allocations. `EscapeSafe` requires every reachable allocation to survive
the invocation's cleanup mark. Its theorem proves that cleanup leaves all those
lifetimes live, including paths through cyclic graphs.

Checking only the directly returned pointer is insufficient: a persistent object
may contain a pointer to a callee's stack local. The negative control demonstrates
that case. The contract conservatively treats even an empty slice as carrying a
lifetime. Bounds, initialization and permissions remain separate obligations.

## Platform boundaries

Platform objects, foreign buffers, callbacks, concurrency and allocator vtables
remain outside admitted execution. Foreign summaries require a justified
connection to the implementation and its calling convention.

For each future external boundary, a verified client must identify the owner,
extent, initialization, aliases, lifetime and reached effects on both success
and failure. Native evidence must also justify the ABI and implementation behind
that contract. A model fault describes an unmet verification obligation; no
runtime checker is added to the Zig executable.
