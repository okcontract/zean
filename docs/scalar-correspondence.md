# Scalar AIR correspondence

`zig build run -- translate --profile scalar --certify` checks the generated
program against `CapturedScalar.decode`. The decoder reads structured AIR, then
projects each type, reference, and primitive to scalar code. It retains both
branches, block continuations, and operation order. Memory effects, source
slice guards, and generic scalar specializations reject.
[Scalar decoder](../lean/Compiler/ZigAir/CapturedScalar.lean)

## Validation on 2026-11-15

- `zig build test -j1` passed with optional upstream-dependent skips.
- `zig build emitted-lean -j1` built the Lean library and checked 48 emitted
  controls across nine profiles. The scalar fixtures received certificates.
- `zig build emitted-control -Demitted-control=scalar-certificate -j1` checked
  an independently recorded scalar model and thirteen mutations. Every mutation
  failed at the kernel decision, including a reached store outside scalar code.
- A fresh capture of zevm's unchanged `word.byte` passed certification and
  ordinary/instrumented object comparison. Lean 4.35.0 checked the certificate
  with one worker and a 4096 MiB limit. Dependency builds used two workers.
- Formatting and diff checks passed.

The certificate checks lowering from the captured data. Inert JSON lifting,
source capture, and native compilation have separate evidence requirements.
[Admission and proof scope](admission.md)
