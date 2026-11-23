# Verify a copy loop

The loop reads initialized `u32` words from a readonly source and writes
them to a destination whose contents may be uninitialized. The caller
supplies the extents, permissions, and disjoint ranges. Disjoint subviews
can share an allocation. [Zig source](copy.zig)

```sh
zig build copy
```

The target checks native cases, Lean contracts from retained AIR, and three
false proofs. Native tests include an empty copy, disjoint subviews, and
the one-word helper's permitted alias.

## Contract and invariant

- `Completed` gives a unit result, a valid heap, copied destination
  contents, and preservation of the source and surrounding memory.
- `Exhausted` permits modeled allocation failure while preserving the
  caller's storage, the source, and surrounding memory.
- `loopInvariant` tracks `index ≤ length`, the initialized copied prefix,
  the saved pointer and counter bindings, and the frame.

The captured program has three local stack slots. `MemoryAir.Bindings`
selects the slots and loop label from the generated data. `air_binding%`
checks and caches those selections, and `Binding.Saved` describes the
stored pointers and index. The invariant establishes their lifetimes.
[Generated model](../../lean/Compiler/Tutorial/Copy/Generated.lean) ·
[Contracts](../../lean/Compiler/Tutorial/Copy/Contracts.lean)

`air_vcgen` and `air_word_finish` discharge the loop obligations with the
client's two outcome lemmas. `copy_safe` covers every fuel value.
`copy_correct` describes execution on return. Proving termination and a
native stack bound requires separate work.
[Verification](../../lean/Compiler/Tutorial/Copy/Verification.lean) ·
[Public theorems](../../lean/Compiler/Tutorial/Copy/Proofs.lean)

The separately captured `copy_word` entry verifies the read-before-write
helper, which allows aliasing. `word_then_contract` composes that effect
with any continuation through `prefix_contract`. The loop itself checks
the inlined instructions with the generic rules.
[Helper proof](../../lean/Compiler/Tutorial/Copy/Helper.lean)

## Counterexamples

| Input | Model result |
| --- | --- |
| Only the first source word initialized | Uninitialized read after the first destination write |
| Length exceeds the source extent | Memory-validity fault |
| Source and destination overlap | The copy can finish and change the source contents |

The overlap witness shows why source preservation needs disjoint views.
Lean checks reached writes and the rejection of the three false proof
clients. [Controls](../../lean/Compiler/Tutorial/Copy/Controls.lean)

## Recapture after an edit

```sh
zig build copy-regenerate -- \
  --toolchain /path/to/toolchain/report.json \
  --output /tmp/copy-evidence \
  --check
```

This checks both captured roots, `copy.copy` and `copy.copy_word`, and runs
the successful and false proof clients against the fresh models. An edit
from `index < length` to `index <= length` adds a read outside the proved
extent. Review the source and invariant if replay fails.
[Toolchain setup](../../docs/toolchain.md) · [Proof guide](../../docs/verification.md)
