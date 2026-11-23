# Native tooling

`zig build` installs the development CLI at `zig-out/bin/zean` and exports
the `zean` Zig module. Use `zig build run -- --help` for CLI options or
`zig build -l` for build targets. [Standalone build](toolchain.md#package-zean) ·
[Project and Lake setup](../examples/client/README.md)

## Capture and translate

Use an instrumented Zig report and fresh output directories outside the
checkout. This example captures one scalar function and asks Lean to check
its correspondence certificate. [Build the instrumented compiler](toolchain.md)

```sh
zig build capture -- \
  --toolchain /tmp/zean-toolchain/report.json \
  --source examples/scalar.zig --root scalar.choose \
  --output /tmp/zean-scalar-air

zig build run -- translate \
  --capture /tmp/zean-scalar-air/report.json --root scalar.choose \
  --profile scalar --namespace Example.Generated \
  --certify /tmp/zean-scalar-certificate --output /tmp/zean-scalar-model
```

Repeat `--root` to select more functions. Profiles without calls require
unique final name components. Use `--source-file` for each local dependency
and `--module NAME=relative/path.zig` for a self-contained named module.
`--source-base` changes where capture looks up those paths and defaults to
the working directory. Capture accepts `--mode Debug`, `ReleaseSafe`, and
`ReleaseFast`. Translation currently admits ReleaseFast AIR.

Translation publishes `Generated.lean` and `manifest.json` together after
every selected root passes. The default namespace is `Zean.Generated`.
`--certify` checks the emitted theorem before publication. See the supported
profiles before selecting source owners or generic instances. [Admission](admission.md)

## Inspect and replay

| Command | Use |
| --- | --- |
| `zig build run -- decode RECORD [PROFILE]` | Inspect one AIR record |
| `zig build admission` | List known operations and their admission checks |
| `zig build audit` | Check memory or source-validity capture fixtures |
| `zig build verify-client` | Capture a client and check its Lean proofs against fresh models |
| `zig build allocator-evaluate` | Check which allocator and list operations can translate. [Example](../examples/allocator/README.md) |
| `zig build benchmark` | Measure proof elaboration with warm dependencies. [Options](verification.md#measuring-proof-cost) |

The counter, buffer, copy, calls, standard-library, and Ziglings examples
have `*-regenerate` targets for fresh capture and proof replay. Their
`--check` compares the model and source identity with the retained version.
[Release checks](validation.md#fresh-capture-release-gate)

## Identity manifests

Translation manifests use `zean.translation.v1` and record source and AIR
hashes, the emitted Lean hash, the interpreter, and correspondence status.
Retained captures keep their original wire tags and hashes.

The executable embeds two build-time identities. The producer inventory
covers `src/`, `build.zig`, and `build.zig.zon`. The library inventory covers
`lean/`, `lean-toolchain`, and `lakefile.lean`. Each digest hashes the sorted
relative paths, with `/` separators, followed per file by NUL, its lowercase
SHA-256, and LF. This includes uncommitted edits. [What the hashes establish](evidence.md)
