# Contributing

Use Zig **0.17.1** and Lean **4.35.0**. Put public build, run, and test targets
in `build.zig`. Use Zig for tools and Lean for semantics and proofs. Prefer
Zig's standard library and source AST.

```sh
zig build test
zig build fmt-check
zig build check -Doptimize=fast
```

Run Lean scopes separately with two workers and keep aggregate verification
memory within 8 GiB. [Validation targets](docs/validation.md)

## Admission and proofs

Add a supported case and a rejection or semantic mutation for each admission
change. Preserve operation order, reached effects, dead-result work, and
ordinary failures. Unsupported constructs must reject.

Keep generated programs apart from handwritten specifications and proofs.
Preserve recorded source, AIR, and capture identities. Reject `sorry`, extra
axioms, and unchecked evaluation shortcuts. State exactly which inputs each
check covers. [Evidence boundaries](docs/evidence.md)

Keep fixtures and explicit mutations in `test/native/cases/`. Use
`test/native/fixtures.zig` and share immutable inputs. Create real files
for source-reading tests and use missing or invalid paths in rejection tests.
Record expected values independently. [Golden results](test/native/cases/golden.zig)

## Toolchains and docs

Set `TMPDIR` to the absolute workspace `.codex-tmp/` path for temporary files.
Use fresh external directories for compiler builds, captures, and run evidence.

When changing Zig versions, update `.zigversion`, `build.zig.zon`, the build
guard, version and revision constants, capture checks, tests, and docs. Check
the patch against a clean release checkout, then build and recapture before
reporting native compatibility. [Toolchain guide](docs/toolchain.md)

Keep setup instructions in one place and link to them from examples. Put the
command and expected result first. Record the inputs and date for measured
results.

Retain copyright notices and upstream fixture licenses. [Apache 2.0](LICENSE)
