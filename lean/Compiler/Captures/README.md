# Retained generated models

`ZigAir/` holds translated scalar, memory, aggregate, byte-access, and loop
programs. Proofs live in `Compiler.Cases` and controls in `Compiler.Tests`.
Tutorial models use `Generated.lean` beside their respective proof modules.

The headers preserve source, AIR, and report hashes from the original
captures. A Lean build checks these retained definitions. A fresh native
claim requires a matching toolchain build and recapture.
[Capture commands](../../../docs/native-tooling.md#capture-and-translate) ·
[Evidence](../../../docs/evidence.md)
