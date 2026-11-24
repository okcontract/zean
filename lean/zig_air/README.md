# Zig AIR instrumentation

Zean patches `SemanticExport.zig` and `SemanticValidity.zig` into an isolated
Zig 0.17.1 compiler build. The native tools in `src/` build the compiler,
capture AIR, and translate supported operations.

Use `zig build toolchain` to build the patched compiler, `zig build capture`
to obtain AIR, and `zig build run -- translate` to emit Lean.
[Toolchain setup](../../docs/toolchain.md) · [Capture and translate](../../docs/native-tooling.md#capture-and-translate)
