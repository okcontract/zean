# Contributing

Use **Zig 0.17.1** and **Lean 4.35.0**. Write executable project code in Zig or
Lean, prefer Zig's standard library and source AST, and keep public build,
run, and test entry points in `build.zig`.

```sh
zig build
zig build test
zig build fmt-check
zig build lean
zig build check -Doptimize=ReleaseFast
```

An admission change needs a supported case and a malformed-input or semantic
mutation control. Preserve ordering, dead-result work, reached failures, and
ownership effects. Unsupported behavior must reject. Never add `sorry`, extra
axioms, or unchecked evaluation shortcuts to pass a proof.

Keep generated program data separate from handwritten specifications and proofs.
Preserve recorded source, AIR, and capture identities. A successful current build
checks the supplied models; it does not produce a fresh native capture or verify
the whole compiler. See [architecture](docs/architecture.md) and
[validation](docs/validation.md).

Add native fixtures and explicit mutations under `test/native/cases/`, using
`test/native/fixtures.zig`. Keep independently recorded expected results in
[`golden.zig`](test/native/cases/golden.zig). Do not derive expected results from
the implementation under test or refresh reference data merely to match a change.
Retained fixtures share immutable inputs; mutations reject stale paths and text.
Synthetic source names are record identifiers. Tests that read source files
create those files explicitly; malformed-path controls deliberately use absent
or invalid names.

Use a workspace-local `.codex-tmp/` directory for temporary files and set `TMPDIR`
to its absolute path before commands that create them. Keep caches, compiler
builds, capture outputs, and verification receipts out of commits. Use a new
output directory for each capture or replay. Run complete Lean builds with two
workers and keep aggregate verification memory within 8 GiB. Avoid concurrent
gates that rebuild or mutate the same inputs.

Changing the target release requires updating `.zigversion`, `build.zig.zon`,
the build guard, version/revision constants, capture checks, tests, and docs.
Check instrumentation against a clean release checkout, then rebuild and capture
before claiming fresh native compatibility. Patch applicability alone is partial
evidence.

Contributions use [Apache 2.0](LICENSE). Retain copyright notices and the licenses
accompanying the pinned upstream exercise fixtures.
