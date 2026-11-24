# Changelog

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
