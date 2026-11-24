# Zean

Zean turns Zig's analyzed intermediate representation (AIR) into executable
Lean models for supported functions. You write contracts and proofs against
the generated program. The memory verifier uses Lean's `Std.WP` and `vcgen`
to generate proof obligations.

## Try a demo

Install Zig **0.17.1** and the pinned Lean toolchain, then run this from the
Zean checkout.

```sh
elan toolchain install leanprover/lean4:v4.35.0
zig build ziglings
```

The demo uses retained captures. It checks the official fixes for Ziglings
038 and 054 natively, then checks initialization and bounds contracts for
the derived kernels in Lean. [Ziglings tutorial](examples/ziglings/README.md)

## Generate models in your project

Build the standalone executable once for your host. It bundles the
instrumented Zig compiler, its library, and its native dependencies.
[Build the compiler and obtain its report](docs/toolchain.md)

```sh
zig build standalone -Doptimize=safe -Dtoolchain-report=/path/to/toolchain/report.json
export PATH="$PWD/zig-out/bin:$PATH"
zean /path/to/project
```

Run `zean` from the target project to use the current directory. Put a
`client.json` at the root for one client or use `zean.json` to list several.
Commit the generated Lean files and `zean.outputs.json` with the Zig sources
and handwritten proofs.

Add Zean's Lean library as a Lake dependency and run `LEAN_NUM_THREADS=2 lake build`
to check correspondence and proofs. Pin the capture target in `zean.json` for
reproducible CI, then use `zean --check` to catch stale or obsolete generated
files. [Client setup and Lake example](examples/client/README.md)

## Examples

| Command | What it checks |
| --- | --- |
| `zig build counter` | A saturating counter, an overflowing edit, and a universal `u32` proof. [Counter](examples/counter/README.md) |
| `zig build buffer` | A guarded write and an off-by-one error inside the backing allocation. [Buffer](examples/buffer/README.md) |
| `zig build copy` | Initialization, non-overlap, and a loop invariant. [Copy](examples/copy/README.md) |
| `zig build calls` | A runtime call chain verified with helper contracts. [Calls](examples/calls/README.md) |
| `zig build stdlib-replace` | The captured `std.mem.replaceScalar(u32)` specialization. [Standard library](examples/stdlib_replace/README.md) |
| `zig build atomic-publication` | A release/acquire proof for a two-slot dispatch table. [Publication](examples/atomic_publication/README.md) |

Two client examples show how to reuse helper contracts across calls.
[Caller and helper](examples/client/calls/README.md) · [Byte scan](examples/client/scan/README.md)

## Scope

Zean rejects AIR outside the selected profile. Lean checks each theorem for
the admitted model and its stated assumptions. Separate evidence is needed
for source validity, native resource bounds, and compiler correctness.
[Admission profiles](docs/architecture.md#supported-routes) ·
[Evidence](docs/evidence.md)

## Development

```sh
zig build test
zig build fmt-check
zig build check -Doptimize=fast
```

Use `zig build -l` to list targets. [Contributing](CONTRIBUTING.md) ·
[Native commands](docs/native-tooling.md) · [Validation](docs/validation.md) ·
[Proof guide](docs/verification.md)

Zean grew out of formal verification work on a Solidity compiler written in
Zig. We wrote the first release over two months with AI assistance, mainly
GPT-6 Astra. [oksolc](https://github.com/okcontract/oksolc)

[Changelog](CHANGELOG.md) · [Apache 2.0 license](LICENSE) · [Attribution](NOTICE)
