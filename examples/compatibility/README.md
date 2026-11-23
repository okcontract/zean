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
| Caller of `std.ascii.upperString` | `loops` rejects `unsupported AIR operation: call` |
| Caller of `std.ascii.lowerString` | `loops` rejects the same runtime call operation |
| Fixed-length pointer-to-slice conversion from Ziglings 054 | `memory` admits `array_to_slice`, preserves the static extent, and passes correspondence |

The ASCII probes exercise a limit of the `loops` profile. The slice probe
checks representation and lowering. The Ziglings tutorial proves a separate
kernel with a runtime length. The release gate runs these probes.
[ASCII drivers](ascii_driver.zig) · [Slice probe](ziglings_slice.zig) ·
[Ziglings proof](../ziglings/README.md) · [Release gate](../../docs/validation.md)
