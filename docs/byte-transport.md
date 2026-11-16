# Copying undefined storage

`@memcpy` transports byte initialization state. It does not require every byte
to have a defined value. A later value read still requires initialization.

The byte-copy semantics distinguish these operations:

| Operation | Undefined source byte |
| --- | --- |
| Value read | Explicit `uninitialized` fault |
| Byte copy | Erase the destination byte's initialization and continue |

Copying still checks lifetime, bounds, destination permission and non-overlap.
Unsupported padding or representation views reject. The model never assigns a
chosen value to undefined bytes. A reached failure preserves earlier writes.

The native control in [`undefined_copy.zig`](../test/native/undefined_copy.zig)
copies a partially initialized array, initializes its missing destination byte,
then reads the complete destination. `zig build test` checks its result both at
compile time and at runtime. The Lean controls independently check transport,
erasure of an old destination value, later uninitialized reads, and reached
effects on bounds failures. These are source/model audit controls, not a proof
of Zig compilation.

Run the focused model checks with:

```sh
zig build lean-module -Dlean-module=Compiler.Tests.ZigAir.MemoryUndefinedTransportAudit
```

Fresh native capture of the fixture also passed ordinary/instrumented object
equality. Translating the whole fixture currently rejects its explicit
undefined-array stores in the memory profile; that boundary remains fail closed.

The generic copy theorems retain their stronger initialized-source contract:
when the source bytes have values, the copied prefix has exactly those values.
Successful copies preserve heap validity, allocation shape and observations
outside the destination, including when undefined bytes are transported.

The model controls distinguish permitted transport from a later value read,
which faults when the copied byte remains uninitialized.
