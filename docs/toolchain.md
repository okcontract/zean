# Build the instrumented Zig compiler

Use a clean Zig checkout at `be248cc1fdc3cc654f9ec8ba68514bcb93b204fe`
(the 0.17.1 release), Zig 0.17.1 for bootstrapping, LLVM and LLD 22.x, and
CMake with Ninja or Unix Makefiles. Build on macOS or Linux and keep the
compiler build and capture outputs outside the Zean checkout.

Check the patch against the release before building, if needed.

```sh
zig build check-patch -- \
  --zig-tree /path/to/clean/zig-0.17.1 \
  --output /tmp/zean-patch-check
```

Build the compiler with AIR capture enabled.

```sh
zig build toolchain -- \
  --zig-tree /path/to/clean/zig-0.17.1 \
  --bootstrap /path/to/zig-0.17.1 \
  --llvm-prefix /path/to/llvm-22 \
  --lld-prefix /path/to/lld-22 \
  --fresh-air --jobs 2 --output /tmp/zean-toolchain
```

`--bootstrap-zig` and `--fresh-air-capture` are aliases. Use
`--cmake-generator 'Unix Makefiles'` if you use Make. Set `--cmake` to choose
the executable, and repeat `--search-prefix` for dependencies such as zstd.
On macOS, pass the SDK's `usr/lib/libc++.tbd` to `--system-libcpp` when
linking against the system C++ library.

The builder archives the clean revision and patches that copy. It checks the
compiler version, source and tool hashes, and compares a smoke-test object
with the bootstrap compiler's output. Inspect `report.json` and the retained
stdout, stderr, and process receipts for the result.

## Package Zean

```sh
zig build standalone -Doptimize=safe -Dtoolchain-report=/tmp/zean-toolchain/report.json
```

The resulting `zig-out/bin/zean` bundles the compiler, its source tree, and
native libraries for the current host ABI. Packaging collects dependencies
with `otool` on macOS or `ldd` on Linux. The executable extracts its compiler
into private run storage and saves the original report with the capture
evidence. [Generate a model](../examples/client/README.md) ·
[Capture AIR directly](native-tooling.md#capture-and-translate)

## Check capture fixtures

Use the same report to run the exporter audit.

```sh
zig build audit -- \
  --profile memory \
  --toolchain /tmp/zean-toolchain/report.json \
  --output /tmp/zean-memory-audit
```

The AArch64 macOS memory audit checks signatures, typed operands, pointer
attributes, undefined stores, and operation coverage in Debug and ReleaseFast.
It includes the validity audit for source spans, SSA dominance, branch
positions, retained bounds, and rejected sentinel and C-pointer slices.
`--profile validity` runs that audit alone. The audits compare ordinary,
captured, and bootstrap object bytes and retain observations and failures.
[Validation and release gate](validation.md)
