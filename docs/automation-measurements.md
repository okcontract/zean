# Compare VC discharge with a shared context

`air_vcgen_shared` uses Lean 4.35's shared-context discharge with the same
checked normalization and finishing rules as `air_vcgen`, the default.
Compare both on the same model and contract. Record elaboration time, memory,
proof edits, and rejection of unsafe mutations.

Copy the buffer proof and change only its `air_vcgen` calls to
`air_vcgen_shared`.

```sh
mkdir -p .codex-tmp
cp lean/Compiler/Tutorial/Buffer/Verification.lean .codex-tmp/BufferShared.lean
# Edit the tactic calls in .codex-tmp/BufferShared.lean.
zig build benchmark -- \
  --proof lean/Compiler/Tutorial/Buffer/Verification.lean \
  --proof .codex-tmp/BufferShared.lean --repeat 3 \
  --output /tmp/zean-vcgen-comparison
```

The target checks dependencies before timing fresh elaboration with warm
imports. Use `zig build run -- benchmark` to repeat the measurement after
checking dependencies. Reports record the exact inputs, cache scope,
elapsed time, and peak memory of the waited child.
[Benchmark options](verification.md#measuring-proof-cost)
