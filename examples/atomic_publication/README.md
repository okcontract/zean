# Publish a dispatch table with release and acquire

`publish` fills two one-byte entries, then sets `ready` to `1` with a release
store. `readEntry` checks the flag with an acquire load. If it sees `1`, it
returns the byte in the requested slot. If it sees `0`, it returns `0` without
touching the table. A published entry can also hold `0`, so a zero result
alone can't tell you which path the reader took. [Zig source](publication.zig)

`zig build atomic-publication` checks the Lean proofs and runs the Zig tests,
including one that starts the writer on a separate thread.

## What the proof covers

The caller gives the writer three distinct bytes and sets the flag to `0`
before sharing it. One writer calls `publish` once. Each reader uses that
same flag and points to one of the two slots. The entries stay read-only after
publication, and all three bytes must stay live through the last read.

Under those assumptions, a reader that sees the writer's `1` gets exactly the
byte the writer put in the requested slot. This holds for any two byte values,
however far the writer has progressed when the reader checks the flag. The
reader can still see the initial `0`. Whether it eventually sees `1` is a
separate question. [Model and theorem](../../lean/Compiler/ZigAir/AtomicPublication.lean)

To see why the order matters, move the release store between the two table
writes. A reader can now see `1` while the second slot is still uninitialized.
Two other counterexamples leave the writes in order but weaken either the
store or the load to `.monotonic`. In both cases the reader loses the
guarantee that it can safely read the slot.
[Lean counterexamples](../../lean/Compiler/Tests/ZigAir/AtomicPublicationControls.lean)

## Check the AIR from Zig

On AArch64 macOS, build the instrumented Zig 0.17.1 compiler from this revision
of Zean. Then capture both functions and check them against the model. Use a
fresh output directory for each command.
[Toolchain build instructions](../../docs/toolchain.md)

```sh
zig build capture -- \
  --toolchain /tmp/zean-toolchain/report.json \
  --source examples/atomic_publication/publication.zig \
  --root publication.publish --root publication.readEntry \
  --output /tmp/publication-air

zig build atomic-publication-check -- \
  --capture /tmp/publication-air/report.json --output /tmp/publication-proof
```

Capture compiles the example twice, with AIR export off and on, and compares
the object files byte for byte. Replay checks the hashes of the saved files.

Lean follows the writer's stores in order. For the reader, it checks which
pointer the acquire load uses, which branch reads the slot, and what each
branch returns. Replay then changes one detail at a time in six copies of the
AIR. One change makes the acquire load read the table slot itself. Lean must
reject that version because the reader never checks the flag. The proof output
directory contains `certificate/Certificate.lean` and a summary in `report.json`.
[AIR decoder](../../lean/Compiler/ZigAir/CapturedPublication.lean)

The checker accepts this version of `publication.zig` and the AIR it expects
for these two functions. The proof relies on the exporter recording the AIR
faithfully and on Zig implementing the modeled release/acquire rule on this
target. Verifying the generated machine code is a separate problem.
