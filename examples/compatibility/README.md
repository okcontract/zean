# Compatibility probes

```sh
zig build compatibility-check \
  -Dtoolchain-report=/path/to/toolchain/report.json \
  -Drelease-output=/tmp/compatibility-evidence
```

Use a fresh evidence directory. The gate compares ordinary and instrumented
objects for three cases.

| Probe | Expected translation result |
| --- | --- |
| Caller of `std.ascii.upperString` | `nested-calls` certifies the actual call chain. `loops` rejects the runtime call. |
| Caller of `std.ascii.lowerString` | Same call-profile checks, with `bit_or` in the byte converter. |
| Fixed-length pointer-to-slice conversion from Ziglings 054 | `memory` admits `array_to_slice`, preserves the static extent, and passes correspondence |

The ASCII probes cover integer switch ranges and the default arm in the
letter classifiers. Native tests check both conversions for all 256 byte
values and check that each destination suffix stays intact. The Ziglings
slice probe checks representation and lowering. Its tutorial proves a
separate kernel with a runtime length.
[ASCII drivers](ascii_driver.zig) · [Slice probe](ziglings_slice.zig) ·
[Ziglings proof](../ziglings/README.md) · [Release gate](../../docs/validation.md)
