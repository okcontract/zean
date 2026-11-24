# Copying undefined storage

`@memcpy` transports byte initialization. Copying an undefined source byte
clears initialization at the destination. A later value read of that byte
faults until it is initialized.

The model checks lifetime, bounds, destination permission, and non-overlap.
Unsupported padding and representation views reject. A fault keeps writes
already reached. On success, a copy preserves heap validity and observations
outside its destination. With initialized source bytes, the copied prefix
contains those exact values.

The native fixture copies a partially initialized array, fills the missing
destination byte, then reads it. `zig build test` checks both comptime and
runtime execution. Fresh capture matched ordinary and instrumented objects.
Full translation of the fixture stops at its explicit undefined-array
stores. [Native fixture](../test/native/undefined_copy.zig)

The Lean controls check transport, erasure of an old value, subsequent
uninitialized reads, and writes that survive a bounds fault.

```sh
zig build lean-module -Dlean-module=Compiler.Tests.ZigAir.MemoryUndefinedTransportAudit
```
