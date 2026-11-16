# Scalar AIR correspondence review

The scalar profile now supports `translate --certify`. Its independent Lean
decoder reuses `Captured`'s raw readers and structured opcode interpretation,
then requires every type, primitive and reference to project to scalar code.
Both branches, block continuations, labels and operation order remain present.
Memory effects and source guards reject. The native admission checks are
unchanged; a certificate remains an additional check before publication.

Self-review covered profile routing, target independence, argument mapping,
integer modes and widths, reached work, proof ownership, publication on failure,
and retained source/native assumptions. The public emitted-control target now
builds the new decoder from clean inputs. Declarative clients accept this newly
certifiable profile while continuing to reject unsupported profiles. The CLI's
workspace identity check expects its build checkout as the working directory.

Validation on 2026-11-15:

* `zig build test -j1` passes; optional upstream-dependent skips remain explicit.
* The complete `zig build emitted-lean -j1` build checks the Lean library and 48
  emitted controls across nine profiles. All supported scalar fixtures gain
  correspondence certificates.
* `zig build emitted-control -Demitted-control=scalar-certificate -j1` checks
  the independently recorded scalar model and thirteen rejected mutations,
  including a reached store that cannot project to scalar code. Every rejection
  must fail at the kernel decision, rather than at an import or unrelated check.
* A fresh native capture of zevm's unchanged `word.byte` passes scalar
  certification with `CapturedScalar.decode`; instrumented and ordinary object
  bytes agree. The certificate is checked with Lean 4.35.0, one proof worker,
  and a 4096 MiB limit; dependency builds use two workers.
* Zig formatting and diff checks pass. No new axiom, unchecked evaluator or
  native proof oracle was introduced.

This certifies AIR-to-generated-model lowering under the retained inert JSON
lifting assumption. It does not certify source safety, source-to-AIR export,
ABI or native compilation. Those manifest fields remain false. Generic scalar
specializations are outside this certificate profile. Bulk compiler, capture,
certificate and control evidence stays outside the checkout.
