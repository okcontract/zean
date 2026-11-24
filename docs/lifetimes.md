# Ownership and lifetime contracts

`Compiler.ZigAir.Verify.Lifetimes` adds sequential contracts for allocation
ownership, byte replacement, and escaping pointers. Native allocator
vtables, `realloc`, and macOS FFI are outside AIR admission.

```sh
zig build lean-module -Dlean-module=Compiler.Tests.ZigAir.MemoryOwnershipControls
zig build lean-module -Dlean-module=Compiler.Tests.ZigAir.MemoryEscapeControls
```

## Ownership

`World.Consistent` pairs a heap with distinct registry entries for live,
writable, persistent allocations. Release checks the allocator identity,
zero offset, declared type, write permission, lifetime, and registry entry.

Release consumes the entry and invalidates every alias of that lifetime.
A second release rejects. Other allocations and ownership entries are
preserved. Reusing a base address starts a fresh lifetime and keeps old
pointers invalid. The caller must relate the registry to actual ownership.
[Ownership model](../lean/Compiler/ZigAir/MemoryOwnership.lean)

## Replacing an allocation

`replaceBytes` validates the old owner, requests a new region with the
required size and alignment, and checks its geometry and separation. It
copies the shorter extent, then releases the old allocation. The allocator's
private effects survive every response. Allocation failure preserves the old
owner. A copy fault keeps the completed prefix and both allocations. Empty
allocations create no releasable entry.
[Replacement model](../lean/Compiler/ZigAir/MemoryOwnedReplacement.lean)

`replaceBytes_success` assumes initialized source bytes, a consistent old
owner, a nonempty replacement, and a returned region satisfying the geometry
contract. It proves the copied prefix, write capability, the new registry
entry, and retirement of the old lifetime. The tail's initialization is
unspecified. Connecting this protocol to a native allocator requires an
admitted implementation or an independently justified external contract.
[Success theorem](../lean/Compiler/ZigAir/MemoryOwnedReplacementContracts.lean)

## Escaping pointers

`EscapeSafe` follows pointers in returned values, optional record fields,
and reachable allocations. Every reachable lifetime must survive cleanup.
The theorem covers cycles. The negative control returns a persistent object
containing a pointer to a stack slot. Even empty slices carry a lifetime
in this contract. State bounds, initialization, and permissions separately.
[Escape model](../lean/Compiler/ZigAir/MemoryEscape.lean)

For foreign buffers, platform objects, callbacks, or concurrent code, a
boundary contract must justify ownership, aliases, live extents, initialization,
and reached effects for each outcome. It also needs evidence for the native
ABI and implementation. [Trust boundaries](architecture.md#trust-boundaries)
