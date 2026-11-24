# Publish a dispatch table with release and acquire

`publish` fills two byte slots, then sets the flag to `1` with a release
store. `readEntry` reads a slot when its acquire load sees `1`. If it
sees `0`, it returns zero without touching the table. A published slot
can also contain zero. [Zig source](publication.zig)

`zig build atomic-publication` checks the Lean proofs and runs the native
tests, including a separate writer thread.

## Contract and counterexamples

The caller provides three distinct live bytes and sets the flag to zero
before sharing it. One writer publishes once. Each reader uses that flag
and one of the two slots, which stay readonly after publication.

If a reader sees the writer's release, it gets exactly the requested byte.
It can also observe the initial flag. Eventual visibility requires a
progress argument. [Model and proof](../../lean/Compiler/ZigAir/AtomicPublication.lean)

Moving the release store between the writes can expose an uninitialized
second slot. Weakening either the load or store to `.monotonic` also loses
the safety guarantee. [Lean counterexamples](../../lean/Compiler/Tests/ZigAir/AtomicPublicationControls.lean)

## Check the captured AIR

Run on AArch64 macOS with a matching instrumented compiler and fresh
output directories. [Toolchain setup](../../docs/toolchain.md)

```sh
zig build capture -- \
  --toolchain /tmp/zean-toolchain/report.json \
  --source examples/atomic_publication/publication.zig \
  --root publication.publish --root publication.readEntry \
  --output /tmp/publication-air

zig build atomic-publication-check -- \
  --capture /tmp/publication-air/report.json --output /tmp/publication-proof
```

Replay checks capture hashes, counts, and matching build settings. Lean
follows the writer's stores and checks the reader's flag pointer, branch,
slot read, and returns. Six AIR mutations must fail correspondence.
For example, changing the acquire load to read the slot breaks the check.
Find the result in `report.json` and `certificate/Certificate.lean`.
[AIR decoder](../../lean/Compiler/ZigAir/CapturedPublication.lean)

The theorem relies on faithful export and the modeled release/acquire rule.
Machine-code preservation needs its own evidence.
