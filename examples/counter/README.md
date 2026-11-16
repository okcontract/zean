# A Zig → Lean verification lifecycle

This tutorial follows one small program through implementation, translation,
proof, and a behavior change. The program advances an unsigned byte counter
without exceeding 255. Version 1 advances by one; version 2 advances by two.
An intentionally broken intermediate update shows Lean catching an overflow.
A `u32` follow-on proves the same property over all 2³² inputs.

The four `Generated.lean` files were produced by zig2lean (now Zean) from
**real native AIR captures** using the instrumented Zig 0.17.1 compiler.
Specifications and proofs are handwritten in separate files. Raw captures,
compiler builds and execution reports stay outside the checkout.

## Run the finished example

Install Zig **0.17.1** and Lean **4.35.0**, as in the root README, then run from
the repository root:

```sh
zig build counter-run
zig build counter
```

The first command runs the working Zig versions, including the `u32` follow-on.
Some representative byte-counter results are:

| Input | Version 1 | Version 2 |
| --- | --- | --- |
| 0 | 1 | 2 |
| 253 | 254 | 255 |
| 254 | 255 | 255 |
| 255 | 255 | 255 |

`zig build counter` checks all 256 inputs in native Zig, checks that each
generated module identifies the current source bytes, checks the Lean proofs
with two workers, and confirms that both an outdated contract and the broken
intermediate update fail. It also tests 4,608 boundary and reproducible sampled
`u32` inputs against a widened specification, and proves the `u32` contract
universally. The broken program is compiled for capture but never run natively.
It uses the checked-in generated modules and does not require rebuilding the
instrumented compiler. `zig build test` also includes the counter's native and
source-identity checks; `zig build lean` includes all its successful proofs.

## Reproduce the complete evidence bundle

After building the instrumented compiler, one command recaptures every stage
and checks the lifecycle against the newly generated definitions:

```sh
COUNTER_TOOLCHAIN=/path/to/instrumented-build/report.json
COUNTER_RUN="$(mktemp -d /tmp/zean-counter.XXXXXX)"

zig build counter-regenerate -- \
  --toolchain "$COUNTER_TOOLCHAIN" \
  --output "$COUNTER_RUN/all" \
  --check
```

This command compares ordinary and capture-enabled native objects, translates
all four programs, and replays the handwritten specifications, successful proofs
and expected proof failures in one temporary Lean module. The replay contains
the fresh generated definitions; it cannot substitute the checked-in generated
modules. Lean processes use two workers and run sequentially.

`--check` compares each source identity and complete program with the retained
module, allowing capture metadata to differ between runs. Omit it when reviewing
a behavior change. The command writes candidates under `*-translation/` and
never overwrites a source, generated module or handwritten proof in the checkout.
If proofs need updating, it fails and retains candidates and diagnostics. After
reviewing the edit and repairing the proof clients, run it again in a new output
directory, then copy the generated modules as shown below.

The output includes `report.json`, a SHA-256 inventory, process logs and
`evidence.tar` with a checksum file. The archive includes source/proof inputs,
AIR, ordinary and captured objects, manifests and replay results; compiler caches
are omitted. It is suitable as a release attachment. It requires the matching
project library and toolchain to reproduce the checks, and its hashes do not
authenticate the producer. Keep the compiler build and this bundle outside the
checkout.

The following steps show what this command automates and which proof changes
you make manually.

## 1. Write the Zig program

[v1/counter.zig](v1/counter.zig) contains the complete function:

```zig
pub export fn advance(value: u8) u8 {
    return if (value < 255) value + 1 else 255;
}
```

`u8` admits values from 0 through 255. The guard is essential: the addition
must execute only when its result still fits in a byte. The export makes Zig
compile the function when we capture this source file as an object.

The independent native reference uses a wider integer before applying the cap:
`@min(@as(u16, value) + 1, 255)`. The tests compare every byte input with this
reference, including the boundary. These finite native tests complement the
Lean proof below.

## 2. Capture AIR and translate it

For regeneration, first build an instrumented compiler using the
[toolchain guide](../../docs/toolchain.md). An ordinary Zig installation runs
the example and tests, but cannot produce the instrumented AIR records.

Choose an external directory and the completed toolchain report. Keep the same
shell variables for the remaining steps:

```sh
COUNTER_TOOLCHAIN=/path/to/instrumented-build/report.json
COUNTER_RUN="$(mktemp -d /tmp/zean-counter.XXXXXX)"

zig build capture -- \
  --toolchain "$COUNTER_TOOLCHAIN" \
  --source examples/counter/v1/counter.zig \
  --root counter.advance \
  --output "$COUNTER_RUN/v1-capture"

zig build run -- translate \
  --capture "$COUNTER_RUN/v1-capture/report.json" \
  --root counter.advance \
  --profile scalar \
  --namespace Compiler.Tutorial.Counter.V1.Generated \
  --output "$COUNTER_RUN/v1-translation"
```

Capture compiles with and without instrumentation, compares the native object
bytes, and checks the requested root and source/tool identities. Translation
admits the supported scalar AIR and publishes `Generated.lean` and
`manifest.json` together. Repeated runs need new output directories.

Copy only the generated module into its checked-in destination:

```sh
cp "$COUNTER_RUN/v1-translation/Generated.lean" \
  lean/Compiler/Tutorial/Counter/V1/Generated.lean
```

The [generated module](../../lean/Compiler/Tutorial/Counter/V1/Generated.lean)
contains an executable `Scalar.Program`, named `fn_advance`. Its source,
capture-report and AIR hashes identify the supplied bytes. The generated code
retains the branch, addition, block result and return. In particular, the
addition uses `.unchecked`, matching the admitted ReleaseFast AIR: its
mathematical bounds still need to be proved.

Do not edit this file to make a proof pass. Its producer is the translation
command above. Keep the capture and translation manifests in `COUNTER_RUN`.

## 3. Write the Lean specification and proofs

[Spec.lean](../../lean/Compiler/Tutorial/Counter/Spec.lean) defines the intended
result independently of the generated instruction sequence:

```lean
def advance (step x : Int) : Int := min (x + step) 255
```

[V1/Proofs.lean](../../lean/Compiler/Tutorial/Counter/V1/Proofs.lean) imports
the generated module. Inside its `Compiler.Tutorial.Counter.V1` namespace, the
handwritten correctness proof is:

```lean
theorem advance_correct (x : Int) (lo : 0 ≤ x) (hi : x < 256) :
    Generated.fn_advance.run [.int false 8 x] =
      .ok (.int false 8 (Spec.advance 1 x)) := by
  by_cases increment : x < 255
  · have result_lo : 0 ≤ x + 1 := by omega
    have result_hi : x + 1 < 256 := by omega
    have cap : x + 1 ≤ 255 := by omega
    simp [Generated.fn_advance, Spec.advance, Int.min_eq_left cap,
      Program.run, Code.eval, Control.Code.eval, controlSemantics, Outcome.ofControl,
      Prim.eval, Ref.eval, Control.Env.set, Value.hasType, Value.type, Value.valid,
      Ty.contains, Ty.lower, Ty.upper, integer, Arithmetic.eval, Comparison.eval,
      bind, Except.bind, lo, hi, increment, result_lo, result_hi]
  · have at_cap : x = 255 := by omega
    subst x
    rfl
```

Lean's mathematical `Int` lets the theorem state the byte preconditions
explicitly. The `.ok` conclusion also proves that execution avoids the
model's malformed-input, illegal-behavior and safety-panic outcomes.

The proof splits on `x < 255`. On the addition path, it establishes
`0 ≤ x + 1` and `x + 1 < 256` before simplifying the generated evaluator.
`omega` discharges these integer inequalities. On the other path, the input
must be 255, and the evaluator returns the cap. No result is assumed for an
unreached branch.

The separate `advance_safe` theorem combines exact execution with the shared
bounds proof. For every valid byte `x`, it establishes:

```lean
∃ result, Generated.fn_advance.run [.int false 8 x] = .ok (.int false 8 result) ∧
  x ≤ result ∧ result ≤ 255
```

Check the handwritten proof clients at any point with:

```sh
zig build counter-proofs
```

## 4. Make a small Zig update

The revised function is preserved alongside the original in
[v2/counter.zig](v2/counter.zig):

```zig
pub export fn advance(value: u8) u8 {
    return if (value < 254) value + 2 else 255;
}
```

Two constants change together. The step becomes two, and the safe-add guard
becomes 254. Merely changing `+ 1` to `+ 2` would make input 254 overflow an
unsigned byte. The two directories let you inspect and run both lifecycle
stages without checking out an older commit.

### Let a real bug fail first

[broken/counter.zig](broken/counter.zig) preserves precisely that incomplete edit:

```zig
pub export fn advance(value: u8) u8 {
    return if (value < 255) value + 2 else 255;
}
```

Its [generated module](../../lean/Compiler/Tutorial/Counter/Broken/Generated.lean)
comes from a separate native capture of the broken source. The translator
accepts the arithmetic because it belongs to the supported fragment; proving
it safe is the proof author's job. At input 254, the guard succeeds but
`254 + 2` does not fit in `u8`. The handwritten
[overflow witness](../../lean/Compiler/Tutorial/Counter/Broken/Proofs.lean)
proves exactly:

```lean
Generated.fn_advance.run [.int false 8 254] = .error .illegalBehavior
```

[BrokenProof.lean](BrokenProof.lean) instead tries to prove a successful return
of 255 at that input. Run `zig build counter-broken-proof` to check that Lean
rejects it. This target expects the specific proof failure; a missing import
or another build error does not count as success. Changing the guard to 254
repairs the bug, producing version 2 above. ReleaseFast illegal behavior is a
model outcome here; it does not promise that the native program traps.

## 5. Regenerate Lean and update the proof

Capture and translate the revised source; changing only the old report's
source hash would not capture the new behavior:

```sh
zig build capture -- \
  --toolchain "$COUNTER_TOOLCHAIN" \
  --source examples/counter/v2/counter.zig \
  --root counter.advance \
  --output "$COUNTER_RUN/v2-capture"

zig build run -- translate \
  --capture "$COUNTER_RUN/v2-capture/report.json" \
  --root counter.advance \
  --profile scalar \
  --namespace Compiler.Tutorial.Counter.V2.Generated \
  --output "$COUNTER_RUN/v2-translation"

cp "$COUNTER_RUN/v2-translation/Generated.lean" \
  lean/Compiler/Tutorial/Counter/V2/Generated.lean
```

The [new generated module](../../lean/Compiler/Tutorial/Counter/V2/Generated.lean)
now compares with 254 and adds 2. Its source and AIR hashes also change.
Regeneration writes no handwritten proof files.

The old exact contract is false for the new program: input 0 returns 2, while
`Spec.advance 1 0` is 1. [StaleProof.lean](StaleProof.lean) tries to prove this
false instance of the old contract. Run:

```sh
zig build counter-stale-proof
```

This target succeeds only when Lean rejects the stale statement with the
expected `rfl` failure. The intentionally failing file lives outside the Lean
library. [Comparison.lean](../../lean/Compiler/Tutorial/Counter/Comparison.lean)
also proves that this old statement is false.

The manual update in
[V2/Proofs.lean](../../lean/Compiler/Tutorial/Counter/V2/Proofs.lean) changes the
exact contract to `Spec.advance 2 x`, splits on `x < 254`, and proves the new
addition bound `x + 2 < 256`. The shared specification and bounds lemma are
reused. `advance_safe` continues to guarantee that the counter never decreases
and never exceeds 255. The comparison proof additionally shows that version 2
returns either the same result as version 1 or one more.

Finish the lifecycle with:

```sh
zig build counter
zig build counter-run
```

When editing either Zig file, the native source-identity check fails until its
generated module is refreshed. After regeneration, a specification-changing
edit can require a manual proof update, as above. Source hashes detect stale
inputs; they do not authenticate a producer or prove a compiler correct.

## 6. Scale the same proof to a 32-bit counter

Exhausting 256 byte inputs is easy. The
[u32/counter.zig](u32/counter.zig) follow-on makes the role of a proof clearer:

```zig
pub export fn advance(value: u32) u32 {
    return if (value < 4294967294) value + 2 else 4294967295;
}
```

Its [generated AIR model](../../lean/Compiler/Tutorial/Counter/Wide/Generated.lean)
was captured independently. The handwritten
[Wide/Proofs.lean](../../lean/Compiler/Tutorial/Counter/Wide/Proofs.lean) states:

```lean
theorem advance_correct (x : Int) (lo : 0 ≤ x) (hi : x < 4294967296) :
    Generated.fn_advance.run [.int false 32 x] =
      .ok (.int false 32 (min (x + 2) 4294967295))
```

The file names the minimum expression `specification`. The proof again splits
at the guard and establishes the addition bounds with `omega`; its reasoning
does not grow with the input range. A second theorem proves no decrease and
the cap. These theorems cover every `u32`, including values beyond the native
test samples. `zig build counter` checks the entire example.

To regenerate this follow-on with the commands above, use source
`examples/counter/u32/counter.zig`, namespace
`Compiler.Tutorial.Counter.Wide.Generated`, and destination
`lean/Compiler/Tutorial/Counter/Wide/Generated.lean`. For the broken stage use
`examples/counter/broken/counter.zig`, namespace
`Compiler.Tutorial.Counter.Broken.Generated`, and destination
`lean/Compiler/Tutorial/Counter/Broken/Generated.lean`.

## Files and evidence boundaries

| Files | Maintained by |
| --- | --- |
| `v1/`, `v2/`, `broken/`, `u32/` | You: original, repaired edit, broken edit and wider program |
| `lean/Compiler/Tutorial/Counter/*/Generated.lean` | Zean: admitted native AIR |
| `Spec.lean`, `*/Proofs.lean`, `Comparison.lean` | You: intended behavior and proofs |
| `run.zig`, `tests.zig`, `identity.zig`, `*Proof.lean` | Example checks and rejection controls |
| External capture reports, AIR, objects and manifests | Capture/translation commands |

The checked-in translations were produced on AArch64/macOS with LLVM and the
pinned instrumented Zig 0.17.1 release. Lean 4.35.0 checks the proofs against
those generated programs. The current capture commands compare ordinary and
instrumented objects, but the theorems establish execution in Zean's
scalar model. Source-to-AIR preservation, instrumentation correctness, native
backend preservation and whole-compiler correctness remain separate
obligations; the manifest verification flags remain false.
