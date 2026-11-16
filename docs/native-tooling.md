# Native tooling

All executable project tools are Zig. `zig build` installs
`zig-out/bin/zean` and exports the `zean` module for Zig package consumers.
Use `zig build run -- --help` for the command interface.

Client manifests use `zean.client.v1`, and translation manifests use
`zean.translation.v1`. The default generated Lean namespace is
`Zean.Generated`. Retained captures keep their original wire identifiers and
recorded hashes.

| Entry point | Purpose |
| --- | --- |
| `zig build toolchain` | Build an isolated instrumented compiler from the pinned public Zig release |
| `zig build check-patch` | Check instrumentation against a clean pinned compiler checkout |
| `zig build capture` | Capture selected AIR roots and source identities, comparing ordinary and instrumented objects |
| `zig build run -- translate` | Validate captured AIR and emit executable Lean definitions and an identity manifest |
| `zig build run -- decode` | Inspect one AIR record through a selected admission profile |
| `zig build audit` | Run independent memory or source-validity fixture audits with a supplied instrumented compiler |
| `zig build admission` | List supported operation obligations and remaining evidence boundaries |
| `zig build verify-client` | Capture and replay a manifest-driven proof client |
| `zig build allocator-evaluate` | Inventory a public standard-library component and record actual admission results |
| `zig build benchmark` | Measure fresh proof elaboration with warm library dependencies |

The [toolchain guide](toolchain.md) explains compiler construction and capture.
The [client tutorial](../examples/client/README.md) shows how to verify another
supported function without adding an adapter to the verifier. The
[admission specification](admission.md) defines the supported fragments.

## Source ownership and specializations

`src/source.zig` uses Zig's tokenizer and AST to select declarations in their
actual file and container owners. `src/declaration_source.zig` binds ordinary
captured functions to their source closure. `src/specialized_source.zig` checks
explicit type arguments and runtime parameter mappings. Matching an unrelated
declaration or a final method name alone is insufficient.

Direct-call closures resolve normalized source paths and exact captured
identities. Relative source components must be real files or directories;
traversal, links, conflicting hashes, unsupported specializations, and
ambiguous owners reject. Local imports and named modules require an explicit
source closure. These checks bind supplied inputs; they do not prove frontend
or source-to-AIR correctness.

## Identity manifests

New translations include the producer source identity and Lean library identity
embedded when the executable was built. The producer inventory covers `src/`,
`build.zig`, and `build.zig.zon`. The library inventory covers `lean/`,
`lean-toolchain`, and `lakefile.lean`.

Each digest hashes sorted relative paths with `/` separators, followed by NUL,
the lowercase SHA-256 of each file, and LF. Uncommitted source edits are included.
Hashes identify bytes; they are not signatures or proofs about the executable.
AIR format tags are versioned wire identifiers, independent of repository paths.

Translation validates every selected root before publishing a bundle into a new
directory. Its manifest records source and AIR identities, the emitted Lean
hash, the selected interpreter, correspondence status, and explicit open claims.
`--certify NEW_DIRECTORY` checks supported AIR-to-model correspondence in Lean
before publication. JSON lifting, source capture, and native refinement remain
separate assumptions.

## Capture and proof replay

The counter, buffer, copy, calls, standard-library replacement, and Ziglings
tutorials expose `*-regenerate` targets. They retain source inputs, captured AIR,
objects, generated models, proof clients, process receipts, and checked output
identities in the requested new directory. `--check` compares retained program
data without replacing its recorded capture identities.

`src/proof_replay.zig` checks imports, redirects clients to fresh generated
modules, and checks named theorem dependencies. `src/evidence.zig` snapshots
explicit inputs and streams hash-checked archives. Expected proof failures
import the same fresh checked definitions as positive clients. Interpreter
faults, native compatibility results, and quantified safety theorems retain
their distinct scopes. See [validation](validation.md).
