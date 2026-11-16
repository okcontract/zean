# Instrumented Zig 0.17.1

The exact release revision is
`be248cc1fdc3cc654f9ec8ba68514bcb93b204fe`. Use a clean checkout at that commit,
a Zig 0.17.1 bootstrap compiler, LLVM 22.x, LLD and CMake/Ninja.
Native process orchestration currently supports macOS and Linux.

First check the release anchors without rebuilding the compiler:

```sh
zig build check-patch -- \
  --zig-tree /path/to/clean/zig-0.17.1 \
  --output /tmp/zean-patch-check
```

The command validates the revision and clean worktree, copies the reached
compiler files to a new directory, and applies the complete instrumentation
there. It leaves the original checkout intact. A successful applicability
check does not establish that an instrumented compiler builds or captures AIR.

Build the isolated instrumented compiler:

```sh
zig build toolchain -- \
  --zig-tree /path/to/clean/zig-0.17.1 \
  --bootstrap /path/to/zig-0.17.1 \
  --llvm-prefix /path/to/llvm-22 \
  --lld-prefix /path/to/lld-22 \
  --fresh-air \
  --jobs 2 \
  --output /tmp/zean-toolchain
```

`--bootstrap-zig` and `--fresh-air-capture` are accepted aliases.
Use `--cmake` to choose CMake and `--cmake-generator` to choose `Ninja` or
`Unix Makefiles`. Repeat `--search-prefix` for explicit dependency prefixes,
such as a required zstd installation. On macOS, `--system-libcpp` can select
the SDK `libc++.tbd`; its isolated build-only patch and file hash are retained.

The native builder:

1. Validates the clean pinned checkout, bootstrap version and LLVM major.
2. Creates and validates a Git source archive, rejecting traversal and links.
3. Hashes the source tree and applies opt-in AIR/validity hooks to the copy.
4. Builds LLVM support and the stripped ReleaseFast compiler, preserving Zig's
   existing 8 GB build memory limit.
5. Checks diagnostics even after a zero exit code, verifies the compiler version,
   and compares LLVM smoke-object bytes with the bootstrap compiler.
6. Rechecks the source tree, bootstrap, link input and original checkout.

Every subprocess gets literal argv, file-backed stdout/stderr and a JSON receipt
with cwd, elapsed time and actual terminal status. Timeouts, interruption and
cancellation clean up the child process group. Failed runs keep their evidence
and a failed report in the requested new output directory.

Capture through `build.zig`:

```sh
zig build capture -- \
  --toolchain /tmp/zean-toolchain/report.json \
  --source examples/scalar.zig \
  --root scalar.choose \
  --output /tmp/zean-capture
```

`--mode` accepts `Debug`, `ReleaseSafe` or `ReleaseFast`. The standalone semantic
translation profiles currently admit ReleaseFast. Repeat `--source-file` for
the explicit local import closure and `--module NAME=relative/path.zig` for
named leaf modules. Every module receives its own mode settings after Zig's
`-M` reset. Local imports are inspected with Zig's tokenizer and AST.
Use `--source-base DIRECTORY` when relative source paths belong to an external
checkout; it defaults to the current directory.

When captured AIR reaches standard-library declarations, capture also archives
their exact source files from the pinned toolchain's `lib/std` tree. Their hashes
must match the AIR identities. A missing source, a changed hash or a conflicting
path rejects capture. This records the declarations actually captured; it does
not make the manifest a complete transitive import inventory.

Capture checks toolchain/source identities before and after compilation,
requires all requested AIR roots, and compares ordinary/captured native object
bytes. Completion and hash checks do not establish frontend, instrumentation,
source-validity or backend correctness. The generated manifests preserve those
open evidence boundaries.

Run the independent exporter fixture gates with the same toolchain report:

```sh
zig build audit -- \
  --profile memory \
  --toolchain /tmp/zean-toolchain/report.json \
  --output /tmp/zean-memory-audit
```

The memory gate checks the complete memory fixture signatures, retained typed
operands, pointer attributes, undefined stores and required operation coverage
in ReleaseFast and Debug. It also runs the validity gate, which checks exact
source spans, SSA dominance, branch positions, retained bounds and explicitly
unsupported sentinel/C-pointer slices. Negative controls reject erased packed
pointer attributes and invalid source operands. `--profile validity` runs that
gate alone. The gates compare ordinary, captured and bootstrap object bytes,
retain observations and failed reports, and recheck their source/tool identities.
They audit capture metadata and native artifacts; their safety and whole-compiler
proof flags remain false.
