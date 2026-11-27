# Changelog

## 0.2.2-dev

- `ReadView.BaseAccessible.element_of_load` proves many-pointer indexing
  from an accessible base and a single initialized element. This supports
  partially initialized lookup tables. [Memory contracts](docs/verification.md)

- `MemoryAir.Bindings.resultOf` selects a unique binding by result type and
  exact operation and operands. Proofs can follow a chain across register
  renumbering and reject changed dataflow. [Checked bindings](docs/verification.md#checked-local-bindings)
- Scalar AIR accepts typed Boolean negation and certifies it with the Lean
  decoder. `Compiler.ZigAir.ResultDecision` supplies decidable success and
  fault observations without requiring equality on the unobserved branch.

- `Generated.lean` puts executable definitions before captured AIR and
  correspondence certificates. Consecutive switch cases align at the same
  indentation. [Native tooling](docs/native-tooling.md)
- `Bindings.callResult` finds the result binding of a unique call by callee
  ID for use with `air_binding%`.
  [Checked local bindings](docs/verification.md#checked-local-bindings)
- `zean verify-client` reports each audited theorem's transitive axiom
  dependencies under `theoremAxioms` in `report.json`, including theorems
  from declared client dependencies.
  [Client proof replay](examples/client/README.md#capture-and-replay-in-one-command)

## 0.2.1

### Project workflow

- Pass `--project` to `zean verify-client` to replay a declared client with
  the project's source mappings and capture target. A client can declare
  dependencies on other clients. Zean captures them in dependency order
  and checks their proof modules together using the fresh models. The
  importing client's report records dependency report digests and audited
  theorems. [Client replay](examples/client/README.md#replay-a-client-declared-in-a-project) ·
  [Client dependencies](examples/client/README.md#replay-a-proof-that-imports-another-client)
- Admission diagnostics locate rejected AIR instructions, report unsupported
  operand kinds, and show the compiler's type rejection reason when available.

### AIR admission

- Byte `@memcpy` checks equality of the original source and destination
  lengths when both are available. Added overlapping byte `@memmove` and
  typed `@memset` with `undefined`, which clears initialization in supported
  scalar slices. [Byte transport](docs/byte-transport.md) ·
  [Admitted operations](docs/admission.md)
- Added unsigned truncating division, exhaustive enums backed by `u2`
  through `u8`, and `?u8` values. Exhaustive enum switches can omit the
  default arm. Register error unions support `try` with `void` or integer
  payloads up to 64 bits. [Admitted operations](docs/admission.md)
- Direct calls check the identities of named `comptime` callbacks and
  zero-storage singleton arguments. Reached zero-storage field projections
  check the owner even when the pointer result is unused, and reject reuse
  of the discarded result. [Call machine](docs/call-machine.md) ·
  [Admitted operations](docs/admission.md)
- Slice guards from inlined helpers are checked against the matching file
  in the retained source inventory.
  [Cross-file slice guards](docs/admission.md#slice-guards-from-inline-helpers)

### Verification

- The `nested-calls` profile certifies calls to `std.ascii.upperString` and
  `std.ascii.lowerString`, including integer switch ranges and defaults.
  The fixed-buffer list example checks the effect of an append within
  reserved capacity and the fault at capacity.
  [ASCII compatibility](examples/compatibility/README.md) ·
  [Reserved append](examples/allocator/README.md#verify-an-append-into-reserved-capacity)
- Added Lean rules for writable typed-array views, checked array ranges and
  one-past slice addresses, reads through nested subobjects, and initialized
  stack spills. The overlapping move contract shows that the destination
  receives the original snapshot of initialized source bytes.
  [Memory contracts](docs/verification.md) ·
  [Move contract](docs/verification.md#prove-a-move-that-can-overlap-its-source)
- Call-machine proofs can replay straight-line memory prefixes and derive
  modeled safety from successful execution. Finite register-only helpers
  preserve the entire modeled state, including on faults.
  [Prefix replay](docs/call-machine.md#prove-a-straight-line-prefix) ·
  [Register-only proof rules](docs/call-machine.md#check-register-only-helpers)

## 0.2.0

### Project workflow

- Run `zean [directory]` to generate Lean modules in your project from
  `client.json` or `zean.json`. The standalone executable bundles the
  instrumented Zig compiler. Commit the generated modules and
  `zean.outputs.json`, then check the proofs with Zean's Lean library as
  a Lake dependency. [Client setup](examples/client/README.md) ·
  [d5e9970](https://github.com/okcontract/zean/commit/d5e9970b8decf65c885734b150f269bb892f3210)
- Use `zean --check` in CI to catch missing, stale, or obsolete modules.
  Pin the capture target and CPU in `zean.json` for repeatable captures.
  Zean marks generated files, protects handwritten inputs, and checks
  output ownership across nested projects.
  [cfa6149](https://github.com/okcontract/zean/commit/cfa614941e3c46381aefa7e4953a75f2e7071256) ·
  [caf3062](https://github.com/okcontract/zean/commit/caf3062effd9dda7382fc46f47640785c9f80c97)
- Use `zean translate --capture` for retained captures. Run
  `translate --certify` with a development build from the Zean checkout.
  [Native tooling](docs/native-tooling.md)
- Project runs keep capture evidence in a private directory outside the
  checkout. When using the bundled compiler, capture records the bundle's
  hash. Packaging rejects ELF `DT_RPATH` and external macOS frameworks.
  [e69f9e3](https://github.com/okcontract/zean/commit/e69f9e352d2199d4acb7e11e922db002c14b262d)
- The README now groups the demos and explains what Zean can verify.
  [53d6dd2](https://github.com/okcontract/zean/commit/53d6dd2ea704fa83f6d5b0a45e520ffffab5b750)

### Verification

- Added a release/acquire publication example with a proof that the Lean
  model matches the captured AIR. The release gate validates replay
  metadata and checks the proof. [0f363db](https://github.com/okcontract/zean/commit/0f363db82f03ac71bcfe5c64fb56ae5181fc755b) ·
  [80ef8e7](https://github.com/okcontract/zean/commit/80ef8e7508d620b1db3d02cccfecf7b7721d469f)
- The `recursive-calls` profile certifies direct self-recursion and mutual
  recursion. [9187fd9](https://github.com/okcontract/zean/commit/9187fd999cccaf1751bddbe069b69fd71a93da2b)
- Zean matches captured methods on types returned by factories to their
  source declarations, including in nested factories.
  [30c0a3c](https://github.com/okcontract/zean/commit/30c0a3c39f582ec2e85b9cb6c54e0f082fba6ee0) ·
  [158e012](https://github.com/okcontract/zean/commit/158e012170d37ce3cea348e24e775b1a36815350)
- Added certified calls to explicit type specializations and concrete
  runtime `anytype` instances. [a7894d2](https://github.com/okcontract/zean/commit/a7894d2a3fd2cf06df75b092421cd6906d7e11e9) ·
  [0076d64](https://github.com/okcontract/zean/commit/0076d6400e78c0667cbd57e9cdd150926d64962e)

These verification changes landed in PR #2.
[2609cea](https://github.com/okcontract/zean/commit/2609cea7abf48384c281888baff1e43146ee50a0)

## 0.1.0 (2026-11-16)

First public release. Zean translated supported Zig 0.17.1 AIR into executable
Lean models and used `Std.WP` and `vcgen` to check memory contracts. The release
included retained captures for the counter, buffer, copy, and Ziglings demos.
[ca23a69](https://github.com/okcontract/zean/commit/ca23a69ebed64c35235abfc746f141c00d8750b4)
