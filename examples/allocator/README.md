# Check allocator-backed list admission

The driver exercises unchanged Zig 0.17.1 `std.ArrayList(u8)` and
`std.heap.FixedBufferAllocator`. It reaches growth, allocation failure,
append, reserved-capacity writes, clear, release, and reset.
[Driver](client.zig)

```sh
zig build allocator-evaluate -- \
  --toolchain /path/to/toolchain/report.json \
  --output /tmp/allocator-evaluation
```

The tool captures all six entry points, compares native objects, inventories
named functions in both library files, and attempts certified call-machine
translation. The inventory includes private and nested declarations.
Uninstantiated declarations are recorded as untested.

## Verify an append into reserved capacity

~~~sh
zig build verify-client -- \
  --manifest examples/allocator/reserved.json \
  --toolchain /path/to/toolchain/report.json \
  --output /path/outside/checkout/reserved-append
~~~

The call closure includes the original list methods and their
capacity assertion. The Lean controls check that an
append with room increments length, writes the new byte, and preserves the
existing byte and capacity. An append at capacity faults before changing the
heap, even with a backing allocation large enough for another byte.
The native test checks that a reserved append keeps the list pointer and
the fixed-buffer allocator cursor. [Model proofs](ReservedProofs.lean)

## Historical results

The ordinary and instrumented objects matched for all six drivers in the
first run. Admission then failed at source identity checks.

| Driver | First rejection |
| --- | --- |
| `append`, `append_slice`, `release`, `reset` | Unsupported call source path |
| `append_reserved`, `clear` | Unsupported declaration owner path |

A later run checked nested source paths and distinguished same-named
callees. It certified `client.reset`, including the actual
`heap.FixedBufferAllocator.reset` body. The other five still failed generic
owner admission in that run. Allocator lifetimes and client safety require
their own contracts. [Ownership models](../../docs/lifetimes.md)

The inventories counted named declarations in the source files.

| File | Count | Recorded SHA-256 |
| --- | ---: | --- |
| `std/array_list.zig` | 127 | `28680fc88fffc34d890244196532193b7e66f909ed05e4d9f02d889ad60c29ef` |
| `std/heap/FixedBufferAllocator.zig` | 17 | `700fd3719674320e769a3c0e4cadcab6f0138564ac1b0030387f5e9376d318a6` |
