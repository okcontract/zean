# Admission and correspondence

Admission is fail-closed. Unsupported source owners, types, targets, instructions,
call identities or specialization metadata must reject before a model bundle is
published. The native decoder checks signatures, domination, structured body
ownership, every instruction's disposition, source guards and captured layouts.
An unused result does not justify removing a reached operation or its faults.

`zig build admission` prints the versioned operation inventory from
`src/admission.zig`. Every reached AIR instruction must occur in that vocabulary
before its profile, payload, type and identity checks run. Entries distinguish
AIR obligations from selected source slice requirements, identify their Lean
interpretations and rejection controls, and explicitly retain
`sourceRequirementsComplete = false`. Listing a tag does not admit arbitrary
instances of it. Translation manifests record the inventory schema.

The semantic interpretation of the supported memory fragment is specified in
[`Captured.lean`](../lean/Compiler/ZigAir/Captured.lean), independently of the Zig
emitter. `translate --profile memory|loops --certify /tmp/check-evidence` emits
inert captured data and a theorem of the form:

```lean
theorem fn_replace_correspondence :
    Captured.decode false fn_replace_captured = some fn_replace := by decide +kernel
```

Lean 4.35.0 checks the complete module before the translator publishes it. The
check uses ordinary kernel reduction, with no native evaluation oracle, added
axiom or assumed correspondence theorem. The evidence directory retains the
input module, compiler receipts and report. A failed check leaves no published
bundle. The manifest records `airCorrespondenceChecked` only after success.

This optional check supports the `scalar`, `memory`, `loops`, `calls`, `call-loops` and
`nested-calls` profiles. Other
profiles reject a certification request. They do not silently fall back to
uncertified translation. Normal translation remains available and reports
`airCorrespondenceChecked: false`. Native admission still runs before a
certificate: the Lean interpretation is a specification of lowering, not a
replacement for every native admission and provenance check.

The scalar interpretation in
[`CapturedScalar.lean`](../lean/Compiler/ZigAir/CapturedScalar.lean) reuses the
independent structured parser and requires a complete scalar projection. Types,
references, both branches, block continuations and every reached primitive are
retained. Any memory operation or source slice guard makes scalar certification
fail. Its integer/Boolean model is independent of pointer layout; it does not
infer target ABI or source safety. `translate --profile scalar --certify ...`
checks `CapturedScalar.decode raw = some program` before publication. Generic
specializations remain outside this scalar certificate profile.

For a concrete generic instance already present in a capture, supply
`--specialized-source /path/to/original.zig`. This deliberately selects one
standalone captured body, even if it was captured as a dependency. It does not
claim to verify its calling wrapper. The source hash, file-level function owner,
explicit comptime type parameters, runtime parameter mapping and lack of
`noalias` are checked. Nested owners, implicit `anytype`, comptime value
parameters, variadics and unsupported layouts reject. The generated model and
certificate retain the instance's concrete runtime types. There is no theorem
about every specialization of the generic source function.

For an ordinary function captured from an imported file, use
`--declaration-source /path/to/original.zig`. This selects one standalone body
and checks the original bytes against both the AIR record and the capture's
explicit source closure. The qualified name must resolve to a real function in
its actual file or nested literal container. Aliases, unrelated nested decoys,
generic parameters, `noalias` and unsupported function attributes reject. This
mode also resolves each member of an admitted direct-call closure. It verifies the selected function under
its contract; it does not establish that every upstream caller meets that
contract. Declaration ownership and hashes do not prove source-to-AIR semantics.

| Captured operation | Model meaning and obligations |
| --- | --- |
| Arguments and constants | Exact runtime index, scalar type and constant; references retain SSA identity |
| Integer arithmetic and casts | Preserve width, signedness and overflow mode; unchecked overflow remains a fault |
| Integer minimum and maximum | Require equal integer types and retain the actual operation; floating-point variants reject |
| Stack allocation | Fresh lifetime identity and uninitialized typed storage; exhaustion remains observable |
| Load and store | Preserve operation order; require live, correctly typed, initialized readable storage or writable storage respectively |
| Pointer arithmetic and casts | Preserve child type, permissions and element scaling; retain liveness, bounds and overflow obligations |
| Slices and projections | Preserve pointer and logical extent; retained source slice guards execute at their captured anchors |
| Byte `memcpy` | Check live source, writable destination and non-overlap; transport initialization byte by byte, including undefined bytes, and retain completed prefix writes on faults. Later value reads require initialization. Unsupported element types and `memmove` reject |
| Array-to-slice conversion | Preserve the array's static element count, pointer and permissions; conversion alone does not access storage |
| Complete record fields | Check the entire owner layout and selected field declaration; padding is not usable typed storage |
| Opaque enum storage | Validate identity, exhaustive tag table, backing width and ABI layout inside complete owners; runtime enum values and operations still reject |
| Direct calls | Resolve declarations and source identities throughout an acyclic closure; execute captured callees, retaining faults and reached effects |
| Conditional branches and blocks | Preserve both branches, block results, labels and continuation order |
| Loops and repeat | Preserve back edges; execution safety covers every prefix and requires a client invariant |
| Return | Preserve the returned reference; invocation checks its type and releases its own stack storage |
| Debug-only instructions | Erased only for the four admitted tags with the explicit debug-only flag |
| Unknown reached instructions | Reject, including instructions whose result is unused |

The certificate lifter has no opcode dispatch, source matching or control-flow
selection. It lifts the entire parsed JSON value to a Lean data tree. Exact
integer values and UTF-8 strings are preserved; unsupported control characters,
floating-point JSON numbers and excessive nesting reject. Interpreting that
data uses separate Lean code for type metadata, operations, references, guards
and structured bodies. The certificate therefore catches disagreement between
the Zig emitter and this interpretation. It does not prove that either semantic
specification agrees with all of Zig.

The emitted-module gate checks certificates for the admitted memory/loop
fixtures and an independently recorded model. Eight expected-failure controls
change an argument index, returned value, opcode, instruction order, reached
work, slice guard, unknown instruction or pointer permission while retaining
the old model. Each must fail at the correspondence theorem. Fresh native copy
capture also exercises certification of both the loop and its helper.

`zig build emitted-control -Demitted-control=scalar-certificate` checks an
independently recorded scalar model and thirteen expected rejections. These change
argument mapping, a comparison constant, arithmetic/opcode overflow mode, branch
order, reached work, branch selection, payload visitation, an unknown opcode,
memory effects, result width, source guards and the returned reference. Full emitted-module
checks also certify all supported scalar fixtures. Negative checks require the
correspondence theorem's failed kernel decision, rather than an unrelated build
or import error.

The remaining trust boundaries are explicit:

- The source owner, frontend and capture exporter must describe the intended
  program, including obligations that optimization could remove. Slice source
  validity coverage is incomplete.
- JSON parsing and inert lifting must preserve the captured bytes' meaning.
  Hashes detect inconsistent artifacts; they do not authenticate source semantics.
- The Lean interpretation and memory library are semantic specifications to
  review. A checked theorem about the wrong specification is still inadequate.
- Native compiler refinement, resource correspondence and target ABI correctness
  require separate evidence. Matching object bytes do not prove these properties.

Certified model equivalence preserves every model execution theorem by equality.
It is neither automatic memory-safety verification nor a whole-compiler proof.

`calls` admits finite callees. `call-loops` allows loops in the root while keeping
its callees finite. `nested-calls` additionally admits looping callees and callers
of those callees. Its independent decoder reconstructs the same interpreter for
each closure member. Recursion and indirect calls remain unsupported. Each
function's chosen interpreter appears in the translation manifest.
