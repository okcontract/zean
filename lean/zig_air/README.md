# Zig AIR instrumentation

`SemanticExport.zig` and `SemanticValidity.zig` are the source modules injected
into an isolated Zig **0.17.1** compiler build. The native implementation in
`src/` handles patching, building, capture, decoding and specialized generation.

Use the root [README](../../README.md), [toolchain guide](../../docs/toolchain.md)
and [native tooling guide](../../docs/native-tooling.md). Public entry points
are `zig build toolchain`, `zig build capture`, `zig build run` and
`zig build generate`.

Unsupported semantics reject. Ordinary installed Zig cannot emit the patched
AIR records. Historical generated models retain their original provenance;
read the [architecture](../../docs/architecture.md) before treating a model
proof as evidence about source validity, native execution or compiler behavior.
