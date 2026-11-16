# Held-out compatibility checks

The [ASCII callers](ascii_driver.zig) exercise two unchanged standard-library routines
that are outside the supported verification route. They are deliberately kept
as rejection controls rather than modified into verified examples.

```sh
zig build compatibility-check \
  -Dtoolchain-report=/path/to/instrumented-build/report.json \
  -Drelease-output=/tmp/compatibility-evidence
```

Use a new output directory. The gate captures both callers with the pinned
compiler, checks ordinary and captured object equality, and requires `loops`
translation of each caller to reject with `unsupported AIR operation: call`.
It also captures the [fixed-length many-pointer conversion](ziglings_slice.zig)
used in Ziglings 054 and requires certified `memory` translation to succeed.
Its static extent survives `array_to_slice`; this admission check does not supply
a caller's memory-safety contract. The [Ziglings tutorial](../ziglings/README.md)
proves a kernel with a runtime extent. The full `release-check` target includes
these gates.

| Component | Current outcome |
| --- | --- |
| `std.mem.replaceScalar(u32)` | Standalone concrete specialization admitted, independently certified and verified under an initialization/write contract |
| Caller of `std.ascii.upperString` | Captured; rejected by the `loops` profile at a runtime call |
| Caller of `std.ascii.lowerString` | Captured; rejected by the `loops` profile at a runtime call |
| Fixed-length many-pointer to slice conversion | Captured and admitted with an independently checked AIR correspondence certificate; no safety theorem for this probe |

The call profiles require an explicit acyclic source closure; `nested-calls`
also admits looping callees. These ASCII wrappers do not establish support for library-wide call
graphs. Their captured dependencies also contain operations outside the present
memory fragment. Admission rejection is not a finding that the Zig code is
unsafe. This small sample is a compatibility boundary, not a representative
coverage study or an end-to-end native safety claim.
