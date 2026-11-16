# Retained generated models

`ZigAir/` contains captured AIR translated into scalar, memory, aggregate,
byte-access, or loop program definitions. Handwritten proof clients live in
`Compiler.Cases`; regression controls live in `Compiler.Tests`. Tutorial captures
remain beside their examples in explicitly named `Generated.lean` modules.

The comments in each generated module retain its recorded source, AIR, and report
hashes. These are input identities, not paths to additional repository files or
claims of a fresh capture. Current capture and translation code lives in `src/`.
See the [toolchain guide](../../../docs/toolchain.md) and
[verification evidence](../../../docs/evidence.md).

New source/native claims require a matching compiler build, new capture, and
proof replay. Building the retained definitions checks their Lean models and
theorems without extending those claims.
