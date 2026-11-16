# Project instructions

Keep task-related temporary files in `.codex-tmp/` at the workspace root and
set `TMPDIR` to its absolute path before commands that create temporary files.
Keep temporary files out of Git commits and delete only files created by the
current task.

Write new project code in **Zig or Lean**. Use Zig 0.17.1 for tools, build
orchestration, generators and tests, and Lean for semantic models and proofs.
Do not add Python scripts or invoke Python from Zig as an implementation.

Use `build.zig` as the public build, run and test interface. Prefer Zig's
standard library, including `std.zig.Ast` for Zig source inspection, over
external scripting languages. Keep generated data distinct from handwritten
logic and document its producer.

Keep test fixtures in Zig, reuse immutable baselines and express mutations
explicitly. Keep independently recorded expected results separate from input
construction. Do not commit bulk generated test snapshots or derive expected
results from the implementation being tested.

Preserve fail-closed admission: unsupported source, AIR operations, layouts,
specializations and invalid identities must reject. Preserve dead-result work,
operation order, ordinary failures and reached effects. Keep source/tool hashes
and historical capture provenance accurate.

Never add `sorry`, extra axioms or unchecked evaluation shortcuts to make Lean
proofs pass. A model proof or successful build is not fresh native capture or
whole-compiler verification. Keep those evidence boundaries explicit.

Run `zig build test` for native regressions and the relevant Lean checks after
changing generated models. Use two Lean workers for the complete library and
keep aggregate verification memory within 8 GiB. Store toolchain builds,
captures and run evidence outside the checkout.
