# Allocator-backed component evaluation

This is a compatibility benchmark, not a verified allocator example. The
driver exercises unchanged `std.ArrayList(u8)` with `std.heap.FixedBufferAllocator`
from the pinned Zig 0.17.1 toolchain. It includes growth, ordinary allocation
failure, bulk append, reserved-capacity mutation, clearing, release and reset.

```sh
zig build allocator-evaluate -- \
  --toolchain /path/to/instrumented-build/report.json \
  --output /tmp/allocator-evaluation
```

The command captures all six driver entry points, compares ordinary and
instrumented native objects, inventories every named function declaration in
both library source files, and attempts certified call-machine translation of
each entry point. Source inventories include private and nested functions and
generic constructors. Byte spans distinguish declarations with the same name.
Uninstantiated declarations are **untested**, not assumed admitted or safe.

The first fresh evaluation recorded these outcomes:

| Driver | Result |
| --- | --- |
| `append`, `append_slice`, `release`, `reset` | Rejected: unsupported call source path |
| `append_reserved`, `clear` | Rejected: unsupported declaration owner path |

All six compiled and the native objects matched. None passed admission, so no
memory-safety proof was attempted. Rejection is not evidence of a bug. These
failures occur at the source-identity boundary, before claiming support for
allocator vtables, generic container owners, allocation failures or release.
The admission checks must be extended with scoped ownership evidence, not
relaxed to make the benchmark pass.

A subsequent fresh evaluation after adding checked nested source paths and
distinct labels for same-named callees certified `client.reset`, including its
actual `heap.FixedBufferAllocator.reset` dependency. The other five entry points
still reject at generic declaration-owner admission. This is AIR correspondence
for the reset body, not a safety contract or a proof of allocator lifetime rules.

The source files contain 127 and 17 named function declarations respectively.
These are file inventories, not counts of distinct methods instantiated for
`u8`. Their recorded SHA-256 identities are:

- `std/array_list.zig`: `28680fc88fffc34d890244196532193b7e66f909ed05e4d9f02d889ad60c29ef`
- `std/heap/FixedBufferAllocator.zig`: `700fd3719674320e769a3c0e4cadcab6f0138564ac1b0030387f5e9376d318a6`

The existing Lean ownership, allocation-failure and copy/release models are
useful foundations for these paths. They do not establish correspondence to
this native component. This benchmark makes that gap measurable and keeps it
visible alongside the supported tutorial clients.
