# Pinned Ziglings exercises

These five files are unchanged copies from
[Ziglings `v0.17.0`](https://codeberg.org/ziglings/exercises/src/tag/v0.17.0),
commit `f594c3f60940506a6b0c8a920e4f440a6e2962dc`:

- [038 exercise source](038_structs2.zig)
- [054 exercise source](054_manypointers.zig)
- [038 correction](038_structs2.patch)
- [054 correction](054_manypointers.patch)
- [MIT license](LICENSE) (Dave Gauer and Chris Boesch)

Upstream has no `v0.17.1` tag. We pin this immutable revision and run its two
corrected exercises with **Zig 0.17.1**, the compiler required by Zean.
This checks these exercises, not compatibility of the entire Ziglings suite.

[`../upstream.zig`](../upstream.zig) records the SHA-256 hashes and explicitly
applies the two official corrections. `zig build ziglings-upstream` checks
the hashes and the corrected programs' output. The uninitialized baseline
of exercise 038 is retained as source and is never executed by this target.
