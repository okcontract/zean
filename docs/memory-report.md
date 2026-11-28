# Memory obligations at Zig source sites

Run the scanner from the Zean checkout. Source paths and the optional intent
file are relative to the project directory.

```sh
zig build memory -- --project ../buzz --source src/editor_storage.zig
zig build memory -- --project ../buzz --intent verification/memory-intent.json \
  --replay /path/to/storage-replay/report.json
```

The JSON inventory uses one-based lines and byte columns and zero-based byte
offsets. Zig's AST supplies declaration ranges and operation sites. A slice
creates bounds and lifetime obligations. A memcpy adds separate source and
destination bounds, separation, initialization, live ranges, contents and
frame obligations. A memmove permits overlap. Allocation, release and returns
from declarations with syntactically visible pointer/slice result types have
their own obligations. Method spellings are candidates. Project intent can
name initialized memcpy wrappers in `copies` to enumerate the same premises at
each caller, additional call spellings in `calls`, and aggregate-returning functions in
`returns`. Each entry under `sources` selects one project-relative Zig file.

## Describe a copy

Import `Compiler.ZigAir.Verify.Bytes`. Use
`CopyRanges state destination source atDst atSrc count contents` for a nonempty
initialized byte copy. The views may share an allocation. Their selected
windows must be disjoint. Use `air_copy_ranges` at a caller. It uses available
facts and arithmetic to fill the record, leaving named Lean goals for the
missing facts. Apply `CopyRanges.copy` with a valid heap and positive count
to obtain the installed bytes and heap frame. The copy automation control withholds separation and checks
the remaining `disjoint` goal. The empty-copy path and each capture adapter's
argument ABI have their own entry conditions.

A complete caller proof is shown below. Delete the `disjoint` argument to
inspect the remaining `case disjoint` goal at `air_copy_ranges`.

```lean
import Compiler.ZigAir.Verify.Bytes

open Compiler.ZigAir.Memory Compiler.ZigAir.Memory.ByteArray

example (valid : s.valid = true) (nonempty : 0 < count)
    (writable : Region s dst true) (readable : Region s src false)
    (dstBound : atDst + count ≤ dst.length) (srcBound : atSrc + count ≤ src.length)
    (initialized : Represents s (src.window atSrc count) bytes)
    (disjoint : Disjoint (src.window atSrc count) (dst.window atDst count)) :
    ∃ after_, ByteRange.copy s ((dst.window atDst count).slice true)
      ((src.window atSrc count).pointer false true) = (.ok (), after_) ∧
      after_.valid = true ∧ Represents after_ (dst.window atDst count) bytes ∧
      HeapFrame (dst.window atDst count) s after_ := by
  have ranges : CopyRanges s dst src atDst atSrc count bytes := by air_copy_ranges
  exact ranges.copy valid nonempty
```

## Review a candidate

Copy the declaration digest, function and operation from the initial scan.
The occurrence counts operations of that name inside the declaration from
zero. List related source files and their SHA-256 under `context` when the
review also depends on helper or caller behavior. The following is an example
sidecar entry for the overlap premise.

```json
{
  "schema": "zean.memory-intent.v1",
  "sources": [{
    "path": "src/editor_storage.zig",
    "reviews": [{
      "function": "copyBytes",
      "operation": "@memcpy",
      "declarationSha256": "e3008cbec81e3c3d664bceb455bbf4cac4ef244790ac4488107f1cba7640b043",
      "obligation": "disjoint",
      "external": true,
      "detail": "The selected byte windows are disjoint for a nonempty copy."
    }]
  }]
}
```

Unreviewed obligations are open. Removing this entry reopens separation.
Use `unsupported: true` for a known admission limitation. For a conditional
proof, supply `manifest`, a fully qualified `theorem` and reviewed `detail`
describing its assumptions. Repeat `--replay` for the relevant trusted local
client reports. Zean checks the project, manifest, input hashes, generated
model, named theorem and prerequisite reports. The output includes the
capture target and SHA-256 of the matching replay. Changed reviewed code
appears in the file's stale list. A stale report cannot discharge a site.

A review connects a theorem's meaning to the operation. An AST match supplies
the location. A proof over a reviewed caller model depends on the model's
relationship to the Zig code. AIR correspondence applies to the captured roots.
