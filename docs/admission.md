# Admission and correspondence

Zean rejects unsupported source owners, signatures, targets, layouts, and
reached AIR. The decoder checks dominance, body ownership, references, and
retained guards. An operation still counts when its result is unused.

`zig build admission` prints the `zean.admission.v1` vocabulary, its Lean
interpretations, and rejection controls. Every reached tag must be listed
and pass its profile, payload, type, and identity checks. The report records
selected source slice and copy-length requirements. Coverage is incomplete.
[Supported profiles](architecture.md#supported-routes)

## Source owners and calls

Zean uses Zig's tokenizer and AST to find the declaring function in its
hashed source file. A call must resolve its qualified owner, source hash,
and runtime signature in the captured closure. Source paths must be
normalized and contained. Traversal, links, and conflicting identities reject.

- `--declaration-source FILE` selects an ordinary captured function from
  an imported file. The source hash must match the AIR and capture closure.
  Nested literal owners must resolve by their full names. Aliases,
  `noalias`, generic parameters, and unsupported attributes reject.
- `--specialized-source FILE` selects one concrete captured body in the
  `memory` or `loops` profile. Its file-level owner must declare explicit
  `comptime T: type` parameters, and the runtime parameter mapping must
  match the instance. Nested owners, implicit `anytype`, comptime values,
  variadics, `noalias`, and unsupported layouts reject.
- Direct-call profiles also admit some concrete generic callees. A method on
  an instantiated type factory needs the captured prototype node to match
  its named source declaration. The decoder checks explicit type arguments
  and can accept concrete `anytype` parameters that stay at runtime. Fresh
  captures mark those as `runtimeAnytype`. Older captures use the source
  parameter shape. A type passed through comptime `anytype` is marked
  `anytypeType` and rejects in both decoders. Only ordinary declarations
  can serve as call-profile roots.

Indirect calls, tail-call requests, missing bodies, foreign calls, and native
allocator vtables reject. Recursion requires `recursive-calls`. The sequential
profiles reject volatile and atomic accesses. [Call machine](call-machine.md) ·
[Dedicated publication checker](../examples/atomic_publication/README.md)

## Operation checks

| Operation | What translation preserves and checks |
| --- | --- |
| Arguments and constants | Exact runtime index, scalar type, value, and SSA identity |
| Arithmetic and casts | Width, signedness, overflow mode, and reached arithmetic faults |
| Integer minimum and maximum | Equal integer types and the selected operation. Floating-point variants reject. |
| Stack allocation | Fresh lifetime, uninitialized typed storage, and modeled exhaustion |
| Loads and stores | Access order, liveness, type, initialization for reads, and permissions for writes |
| Pointer arithmetic and casts | Child type, permissions, scaling, bounds, and overflow |
| Slices and projections | Pointer and logical extent. Source slice guards execute at their recorded anchors. |
| Byte `memcpy` | Equality of lengths supplied by both source operands, live extents, write permission, non-overlap, and per-byte initialization. A fault preserves writes already reached. |
| Byte `memmove` | The same length, extent, permission, and initialization checks, with backwards traversal when the destination overlaps the source to its right. |
| Array to slice | Static extent, pointer, and permissions. Conversion itself performs no storage access. |
| Record fields | Complete owner layout and declared field. Validated zero-storage fields retain their declaration indices and contribute no heap storage. Projections into them and accesses to padding reject. |
| Opaque enum storage | Identity, exhaustive tag table, backing width and layout. Runtime enum values and operations reject. |
| Direct calls | Exact callee identity and execution of its captured body, including faults and effects |
| Branches, blocks, and loops | Branch selection, labels, block results, continuations, and back edges |
| Integer switches | Typed, disjoint constant items and inclusive ranges. All bodies and the explicit default must pass admission. |
| Return | Result type and reference, followed by release of private stack storage |
| Debug metadata | Erasure only for the four admitted tags with the explicit debug flag and unit type |
| Unknown reached tags | Rejection, including operations with unused results |

Sema records copy lengths before slice decay and array-pointer upgrades.
When both operands supplied a length, the model checks equality at the copy
instruction before its first write. A runtime equality without a supported
AIR anchor rejects. Records with source copy operations require a capture
that records those obligations.

## Correspondence checks

`zean` emits a certificate for each configured model. Use
`zig build run -- translate` with `--certify /tmp/check-evidence` to check a
certificate before publication. An unsupported profile rejects the request.

The lifter turns the full parsed JSON into inert Lean data. It preserves
integers and UTF-8 strings and rejects floating-point numbers, unsupported
control characters, and excessive nesting. The independent Lean decoder
interprets that data. A memory certificate has this form.

```lean
theorem fn_replace_correspondence :
    Captured.decode false fn_replace_captured = some fn_replace := by decide +kernel
```

The kernel checks the equality by reduction. The scalar decoder projects
every reached primitive, type and reference, including both branches and
block continuations. Memory effects and source slice guards reject in that
profile. The call-table decoders resolve the entire emitted closure.
[Memory decoder](../lean/Compiler/ZigAir/Captured.lean) ·
[Scalar decoder](../lean/Compiler/ZigAir/CapturedScalar.lean)

`airCorrespondenceEmitted` records the presence of a theorem.
`airCorrespondenceChecked` records a successful in-command Lean check.
When using the project command, check the emitted theorems with Lake.
JSON lifting, source capture, and native compilation are trust boundaries.
[Verification evidence](evidence.md)

`zig build emitted-lean` compiles actual emitted models and checks deliberate
differences in returned values, reached work, operation order, guards and
permissions. The scalar-specific target also checks an independently
recorded model. Each mutation must fail at the correspondence theorem.

```sh
zig build emitted-control -Demitted-control=scalar-certificate
```
