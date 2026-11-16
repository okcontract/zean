# Checked bindings and proof-cost comparisons

Client annotations can select arguments by runtime parameter index and local
allocations or casts by type. A selection must be unique. Missing or ambiguous
matches reject. `air_binding%` caches the selection with a kernel-checked
equality; it uses no unchecked evaluation.

The copy-loop tutorial uses these selectors for invariant bindings. Controls
cover register renumbering, unrelated insertions, absent arguments and duplicate
matches. Type-based selection remains conservative when multiple slots share
the same type. The capture data does not provide stable source-local names.

`air_vcgen_shared` evaluates Lean 4.35's shared-context discharge interface.
It uses the same checked normalization and finishing rules as `air_vcgen`.
The latter remains the default. Compare both against the same program and
contract, recording elaboration time, memory, proof maintenance and rejected
unsafe mutations before changing that default.

To make a local comparison with the current buffer contract, create a temporary
variant of the existing proof and replace its `air_vcgen` calls with
`air_vcgen_shared`:

```sh
mkdir -p .codex-tmp
cp lean/Compiler/Tutorial/Buffer/Verification.lean .codex-tmp/BufferShared.lean
# Edit only the tactic calls in .codex-tmp/BufferShared.lean.
zig build benchmark -- \
  --proof lean/Compiler/Tutorial/Buffer/Verification.lean \
  --proof .codex-tmp/BufferShared.lean --repeat 3 \
  --output .codex-tmp/vcgen-comparison
```

The command first checks the included library, then measures fresh main-file
elaboration with warm imports. Once dependencies are checked, `zig build run --
benchmark` invokes the same tool without repeating that prerequisite. Reports
retain source snapshots, identities, process arguments, worker limits, elapsed
time and peak waited-child memory. They describe their exact inputs and cache
state, not general performance of other programs.
