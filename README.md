# Zean

**Translate Zig functions into executable Lean models and prove their behavior.**

Zean captures Zig's analyzed intermediate representation (AIR) and emits
Lean program definitions. You write specifications and proofs in separate
files, then regenerate the model when the Zig code changes. Translation is
restricted to supported operations; unsupported code is rejected.

For memory safety, a reusable verification library generates proof obligations
from the translated program using Lean 4.35's `Std.WP` and `vcgen`. You supply
contracts and loop invariants, then discharge the remaining obligations in Lean.
Start with [Ziglings 038 and 054: from fixes to memory contracts](examples/ziglings/README.md).
It pairs pinned upstream exercises with captured runtime kernels, short
contract-driven proofs, and counterexamples for missing initialization and
invented slice bounds. Run `zig build ziglings` to check the demonstration.

Continue with the [buffer update](examples/buffer/README.md), or follow the
[copy-loop tutorial](examples/copy/README.md) for initialization, framing and
helper contracts. The [verification guide](docs/verification.md) explains how
to apply the same machinery to another supported function.
The [manifest-based client](examples/client/README.md) captures and verifies
your own function without adding a new tutorial command or changing the verifier.
Its [caller/helper variant](examples/client/calls/README.md) uses the explicit
call-stack interpreter and verifies a caller from a separately checked helper
contract, with readable generated function tables.
The [byte-scanning client](examples/client/scan/README.md) adds a loop invariant,
early returns, and a helper call inside the loop.
For runtime helper calls, the [call-chain example](examples/calls/README.md)
shows a caller reusing checked callee contracts across actual runtime calls.
The [standard-library example](examples/stdlib_replace/README.md) goes beyond
the tutorials: it verifies an unchanged `std.mem.replaceScalar(u32)` specialization,
with a separately checked AIR-to-model correspondence certificate.
The [compatibility probes](examples/compatibility/README.md) also show examples
that still reject, so these results should not be read as general Zig support.

## Try the Ziglings memory-safety demo

With **Zig 0.17.1** and **elan** installed, run from the repository root:

```sh
elan toolchain install leanprover/lean4:v4.35.0
zig build ziglings
```

The [tutorial](examples/ziglings/README.md) follows two familiar Ziglings lessons:

| Exercise | Checked property of the derived runtime kernel |
| --- | --- |
| 038: initialize both characters | Reading either gold slot is safe after both writes, without assuming initial contents |
| 054: give a many-pointer a length | Reads stay within the caller's initialized byte region and preserve memory |

You supply the caller contracts; reusable verification rules discharge the
memory obligations. Broken variants demonstrate an uninitialized read and an
invented slice extent. The command checks the proofs, requires false claims to
fail, and runs the two officially corrected upstream exercises on Zig 0.17.1.

The formal proofs cover the captured runtime kernels described in the tutorial.
The original exercises, including their printing code, receive separate native
compatibility checks. Retained captures let you run the demo without building
an instrumented compiler.

## Follow a small program update

Start with a counter that advances without overflowing:

```zig
pub export fn advance(value: u8) u8 {
    return if (value < 255) value + 1 else 255;
}
```

The [handwritten proof](lean/Compiler/Tutorial/Counter/V1/Proofs.lean) establishes
that, for every valid byte input `x`, the generated model returns
`min(x + 1, 255)` successfully. A second theorem proves that the result never
decreases and never exceeds 255.

```sh
zig build counter-run
zig build counter
```

`counter-run` runs the working Zig examples. `counter` checks their native
results, generated-source identities, Lean proofs, and expected proof failures.
The example includes generated models from real native AIR captures, so these
commands need no instrumented compiler.

The [counter tutorial](examples/counter/README.md) follows the complete lifecycle:

1. Write the byte counter and prove its behavior.
2. Change the step to two and see an incomplete edit overflow at input 254.
3. Fix the guard, regenerate the model, and update the proof.
4. Apply the same reasoning to a `u32` counter, proving the contract for all
   2³² inputs without enumerating them.

## Prove a buffer update safe

The [buffer tutorial](examples/buffer/README.md) takes the next step: prove that
a Zig function updates exactly one element of a writable buffer and preserves
surrounding memory. Its Lean proofs cover arbitrary valid caller heaps, buffer
contents and 64-bit indices under explicit storage contracts.

```sh
zig build buffer-run
zig build buffer
```

An off-by-one edit demonstrates both an invalid access and a write outside a
smaller logical buffer that still lies inside allocated memory. A repaired
version restores the contract. Like the counter, it includes real captured
models, separate handwritten proofs, and automated fresh capture and proof
replay. These are memory-safety proofs for the supported models; caller storage
assumptions and source/compiler correspondence remain explicit.

The [copy example](examples/copy/README.md) uses the same verifier for a loop
over a readonly source and an initially uninitialized destination. Its contract
proves memory safety at every execution prefix; successful completion copies
the contents and preserves the source and surrounding memory. Run `zig build copy`
to check the proofs, native controls and three intentionally false proof clients.

## What a proof establishes

```text
Zig source → captured AIR → generated Lean model → handwritten Lean proofs
```

Lean checks proofs about execution in the selected model, including its explicit
failure outcomes. The counter's successful-return theorem rules out arithmetic
faults for every input in its stated domain.

Source admission, the Zig frontend, capture instrumentation, and the native
backend remain trusted boundaries. Model proofs and matching native object
bytes do not establish whole-compiler correctness. See
[architecture and trust](docs/architecture.md) for the exact boundaries.

## Capture and translate a program

To generate a new model, first build an instrumented Zig compiler using the
[toolchain guide](docs/toolchain.md). An ordinary Zig installation can run the
examples and tests; producing AIR records requires the instrumented compiler.
Native capture tooling supports macOS and Linux.

For example, capture and translate the original counter:

```sh
zig build capture -- \
  --toolchain /path/to/instrumented-build/report.json \
  --source examples/counter/v1/counter.zig \
  --root counter.advance \
  --output /tmp/counter-capture

zig build run -- translate \
  --capture /tmp/counter-capture/report.json \
  --root counter.advance \
  --profile scalar \
  --namespace MyCounter.Generated \
  --output /tmp/counter-model
```

The output bundle contains:

| File | Purpose |
| --- | --- |
| `Generated.lean` | Executable program data; regenerated by the translator |
| `manifest.json` | Source, AIR, capture, producer and model identities, plus verification scope |

Translation validates every selected root before publishing the bundle. Use a
new output directory for each run, and keep captures and compiler builds in a
separate working directory. Repeat `--root` to select more functions; their
final name components must be unique.

For `scalar`, `memory` and `loops`, add `--certify /tmp/certificate-evidence` to check
AIR-to-model correspondence in Lean before publication. The generated theorem
compares an independent Lean interpretation of the captured data with the emitted
program. This checks the lowering step; source capture, JSON lifting and native
code generation remain trusted. See the [admission specification](docs/admission.md).

Build the reusable model library and check the generated module:

```sh
zig build lean-framework
elan run leanprover/lean4:v4.35.0 lake env lean /tmp/counter-model/Generated.lean
```

Add your specification and proofs in separate Lean files. The tutorial shows
how to organize those files and update them after a source change.

## Supported fragments

| Translation profile | Supported operations |
| --- | --- |
| `scalar` | Selected integer/Boolean operations, casts and structured control |
| `memory` | Typed pointers, allocation, loads/stores and retained slice guards |
| `loops` | Memory operations with resumable loops |
| `aggregate` | Complete aggregate declarations, fields and aggregate operations |
| `word-bytes` | Restricted initialized `u32` byte views with checked provenance |
| `word-byte-loops` | Word-byte access with resumable loops |
| `calls` | Finite memory programs with an admitted direct-call closure |
| `call-loops` | Looping callers with finite, separately verified callees |
| `nested-calls` | Acyclic calls to looping callees, with safety over all finite observation budgets |

These profiles describe admitted AIR, rather than general Zig language support.
Standalone translation currently admits ReleaseFast AIR. Memory profiles
have additional target and contract restrictions; see the
[supported routes](docs/architecture.md#supported-routes).

The [native tooling guide](docs/native-tooling.md) describes capture, source-owner
validation, certified translation, and proof replay. The repository includes
the inputs needed for its portable examples and regression checks. New captures
require an instrumented build of the public, pinned Zig release.

## Build and contribute

Versions are pinned in [.zigversion](.zigversion) and
[lean-toolchain](lean-toolchain). The build uses elan by default; select an
existing matching Lake executable with `-Dlake=/path/to/lake`.

| Command | What it does |
| --- | --- |
| `zig build` | Build and install the native CLI |
| `zig build test` | Run native translation, admission, process, and tutorial regressions |
| `zig build lean-core` | Check the core verification API and its dependencies |
| `zig build lean-framework` | Check reusable semantics, optional verification domains and correspondence |
| `zig build lean-examples` | Check tutorial and component proof clients |
| `zig build lean-regressions` | Check retained captures, standard-library cases, controls and baselines |
| `zig build lean` | Check the full Lean library and admission controls with two workers |
| `zig build fmt-check` | Check Zig formatting |
| `zig build check -Doptimize=ReleaseFast` | Run portable checks, including compilation of newly emitted Lean |
| `zig build counter` | Check the complete counter lifecycle |
| `zig build buffer` | Check buffer safety, update behavior and off-by-one proof failures |
| `zig build copy` | Check copy-loop safety, helper contracts and initialization/bounds/aliasing controls |
| `zig build calls` | Check a captured call chain through reusable callee contracts |
| `zig build stdlib-replace` | Check an unchanged standard-library loop and its initialization/permission controls |
| `zig build wp-proofs` | Check generic verification rules against interpreter and fault controls |
| `zig build benchmark -- --output /tmp/proof-cost` | Measure fresh proof elaboration with warm library dependencies |

To recapture the tutorial and replay its proofs against fresh definitions:

```sh
zig build counter-regenerate -- \
  --toolchain /path/to/instrumented-build/report.json \
  --output /tmp/counter-evidence \
  --check
```

This also produces an evidence archive containing source and proof inputs,
AIR, native objects, manifests and process receipts. The
[validation guide](docs/validation.md) documents the full `release-check` gate,
including fresh memory and slice audits. Portable CI runs native Debug tests
and ReleaseFast checks. See [contributing](CONTRIBUTING.md) for fixture and proof
conventions.

## Explore the repository

- [Counter tutorial](examples/counter/README.md): program, capture, proof and update.
- [Buffer tutorial](examples/buffer/README.md): memory safety, surrounding-memory preservation and a broken update.
- [Copy tutorial](examples/copy/README.md): loop invariants, initialization and compositional inline-helper contracts.
- [Verification guide](docs/verification.md): contracts and automation for other supported programs.
- [Architecture](docs/architecture.md): translation routes, models and trust boundaries.
- [Toolchain guide](docs/toolchain.md): build the instrumented compiler and capture AIR.
- [Native tooling](docs/native-tooling.md): capture, source ownership, translation and proof replay.
- [Validation](docs/validation.md): regression coverage, release checks and recorded evidence.

Implementation lives in [`src/`](src/), models and proofs in [`lean/`](lean/),
and regression fixtures in [`test/`](test/). Generated programs are kept
separate from handwritten proofs.

Licensed under [Apache 2.0](LICENSE). See [NOTICE](NOTICE) for attribution.
