# Verify your own supported function

This client writes one word through a caller-supplied pointer. Its contract
requires a valid, writable, nonempty region and proves that every finite
execution prefix avoids modeled memory faults. Initial contents are arbitrary.
The proof uses the generic verifier and contains no instruction numbers.

`client.json` names the Zig source, capture roots, generated module, generic
library imports, ordered proof modules, and theorem obligations. New clients
need no changes to the verifier or tutorial enumeration.

The [caller/helper variant](calls/README.md) uses the explicit call-stack machine
and a separately checked helper contract. Its manifest selects
`"executionModel": "call-machine"` with a call profile. All call profiles use
this representation by default; the field is an optional explicit assertion.
Unknown models and incompatible profiles reject before capture.

With an instrumented Zig 0.17.1 [toolchain report](../../docs/architecture.md), run:

```sh
zig build verify-client -- \
  --manifest examples/client/client.json \
  --toolchain /path/to/toolchain/report.json \
  --output /tmp/cell-verification
```

Use a new output directory for each run. Paths in the manifest are relative to
the manifest's directory. List local Zig dependencies in `sources`; named Zig
modules and standalone generic specializations are not part of this first
manifest schema. Those constructs retain their existing dedicated workflows.

The command captures the source, compares instrumented and ordinary native
objects, translates it, checks AIR correspondence, and replays the proofs on
the fresh model. It retains inputs, generated modules, process receipts, and
`report.json`. A failed stage leaves a failed report. Proof workers run serially
with a 4 GiB process limit; reusable library builds use two workers.

Proof imports must name a declared generic library, the generated module, or an
earlier proof module. Use one ordinary `import` per line; module modifiers are
not supported. Replay redirects dependencies to fresh module names so checked-in
generated modules cannot satisfy a new obligation. Every named theorem must
be declared in a freshly checked client proof module and depend only on Lean's
standard logical axioms. `sorry` and added axioms fail the audit.

To try a failing update, add a second write at index one through a many-pointer
cast. The current contract permits regions of length one, so the original
proof cannot establish its safety. Strengthen the contract only if the callers
actually satisfy that stronger requirement.

The report distinguishes checked model proofs and native object comparison
from source safety and compiler preservation. Selecting theorem names does not
make their statements meaningful automatically: review the contracts. This
client proves memory safety under its precondition, not that every Zig caller
satisfies that precondition, nor that native allocation resources match the
model.
