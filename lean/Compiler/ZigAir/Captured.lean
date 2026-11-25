/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryExecution

/-! An independent interpretation of the captured AIR data format. The Zig
certificate producer only lifts JSON into `Raw`; it does not select opcodes,
types, bodies or references. A certificate equates this interpretation with the
separately emitted program using kernel reduction. This is an AIR-to-model
check, not a proof of the exporter, frontend, source guards or native compiler.
The interpretation is intentionally restricted to the memory/loop vocabulary.
It preserves reached work, order and source guards; unknown instructions fail.
Native admission additionally checks dominance, signatures and identities. -/
namespace Compiler.ZigAir.Captured
open Memory MemoryAir

inductive Raw where
  | null | boolean (value : Bool) | number (value : Int) | string (value : String)
  | array (values : List Raw) | object (fields : List (String × Raw))
  deriving Repr

def Raw.isNull : Raw → Bool | .null => true | _ => false

def Raw.get : Raw → String → Option Raw
  | .object fields, key => (fields.find? (fun field => field.1 == key)).map Prod.snd
  | _, _ => none

def Raw.text : Raw → Option String | .string value => some value | _ => none
def Raw.integer : Raw → Option Int | .number value => some value | _ => none
def Raw.natural : Raw → Option Nat
  | .number value => if value ≥ 0 then some value.toNat else none
  | _ => none
def Raw.flag : Raw → Option Bool | .boolean value => some value | _ => none
def Raw.list : Raw → Option (List Raw) | .array values => some values | _ => none

def Raw.textAt (raw : Raw) (key : String) : Option String := raw.get key >>= Raw.text
def Raw.natAt (raw : Raw) (key : String) : Option Nat := raw.get key >>= Raw.natural
def Raw.boolAt (raw : Raw) (key : String) : Option Bool := raw.get key >>= Raw.flag
def Raw.listAt (raw : Raw) (key : String) : Option (List Raw) := raw.get key >>= Raw.list

def require (condition : Bool) : Option Unit := if condition then some () else none

private def layoutMatches (raw : Raw) (ty : Ty) : Option Unit := do
  let layout ← ty.layout
  require ((← raw.textAt "kind") == "abi" && (← raw.natAt "bytes") == layout.bytes &&
    (← raw.natAt "alignment") == layout.alignment)

/-- Structural insertion keeps the bounded field table reducible in the kernel.
The subsequent layout check rejects overlaps, including equal offsets. -/
private def insertField (field : Nat × Field) : List (Nat × Field) → List (Nat × Field)
  | [] => [field]
  | first :: rest => if field.1 ≤ first.1 then field :: first :: rest else first :: insertField field rest

/-- Inactive enum storage has its complete captured tag table checked, but no
runtime enum values or scalar views are introduced. The nominal record type
only supplies extent and alignment to its enclosing owner. -/
private def opaqueEnum (raw : Raw) : Option Ty := do
  let identity ← raw.get "identity"
  let name ← identity.textAt "name"
  let hash ← identity.textAt "sourceSha256"
  require (!name.isEmpty && !(← identity.textAt "sourceFile").isEmpty && hash.length == 64 &&
    hash.toList.all (fun ch => ch.isDigit || ('a' ≤ ch && ch ≤ 'f')))
  let backing ← raw.get "backingType"
  let bits ← backing.natAt "bits"
  require ((← backing.textAt "kind") == "int" && (← backing.textAt "signedness") == "unsigned" &&
    0 < bits && bits ≤ 64 && !(← raw.boolAt "nonexhaustive"))
  let size := if bits ≤ 8 then 1 else if bits ≤ 16 then 2 else if bits ≤ 32 then 4 else 8
  let fields ← raw.listAt "fields"
  require (!fields.isEmpty && fields.length ≤ 256)
  let tags ← fields.zipIdx |>.mapM fun (field, index) => do
    let name ← field.textAt "name"
    let value ← field.natAt "value"
    require ((← field.natAt "index") == index && !name.isEmpty && value < 2 ^ bits)
    pure (name, value)
  require (decide (tags.Pairwise fun left right => left.1 ≠ right.1 ∧ left.2 ≠ right.2))
  let type := Ty.record ("enum:" ++ name) ⟨size, size⟩
  layoutMatches (← raw.get "layout") type
  pure type

def typeOf : Nat → Raw → Option Ty
  | 0, _ => none
  | fuel + 1, raw => do
    match ← raw.textAt "kind" with
    | "void" => pure (.scalar .unit)
    | "bool" => pure (.scalar .bool)
    | "int" =>
      let bits ← raw.natAt "bits"
      let signed ← raw.textAt "signedness"
      require (bits ≤ 512 && (signed == "signed" || signed == "unsigned"))
      pure (.scalar (.int (signed == "signed") bits))
    | "pointer" =>
      let flags ← raw.get "flags"
      let size ← flags.textAt "size"
      require (["one", "many", "slice"].contains size)
      let writable := !(← flags.boolAt "isConst")
      require (!(← flags.boolAt "isVolatile") && !(← flags.boolAt "allowZero") &&
        (← flags.textAt "addressSpace") == "generic" && (← flags.get "vectorIndex").isNull &&
        (← flags.get "alignment").isNull && (← raw.get "sentinel").isNull &&
        (← flags.natAt "hostSizeBytes") == 0 && (← flags.natAt "bitOffset") == 0)
      let child ← typeOf fuel (← raw.get "child")
      let ty := if size == "slice" then Ty.slice writable child else Ty.pointer writable (size == "many") child
      layoutMatches (← raw.get "layout") ty
      layoutMatches (← raw.get "pointeeLayout") child
      pure ty
    | "array" =>
      require (← raw.get "sentinel").isNull
      let ty := Ty.array (← raw.natAt "length") (← typeOf fuel (← raw.get "child"))
      layoutMatches (← raw.get "layout") ty
      pure ty
    | "enum" => opaqueEnum raw
    | "struct" =>
      require (["auto", "extern"].contains (← raw.textAt "containerLayout"))
      let identity ← raw.get "identity"
      let name ← identity.textAt "name"
      require (!name.isEmpty && !(← identity.textAt "sourceFile").isEmpty &&
        (← identity.textAt "sourceSha256").length == 64)
      let rawLayout ← raw.get "layout"
      require ((← rawLayout.textAt "kind") == "abi")
      let layout : Layout := ⟨← rawLayout.natAt "bytes", ← rawLayout.natAt "alignment"⟩
      let rawFields ← raw.listAt "fields"
      require (!rawFields.isEmpty && rawFields.length ≤ 64)
      let fields ← rawFields.zipIdx |>.mapM fun (rawField, index) => do
        require ((← rawField.natAt "index") == index && (← rawField.get "explicitAlignment").isNull &&
          !(← rawField.textAt "name").isEmpty)
        let child ← typeOf fuel (← rawField.get "type")
        let field := match child with | .scalar scalar => Field.scalar scalar | _ => Field.object child
        pure ((← rawField.natAt "offset"), field)
      let ty := Ty.aggregate name layout (fields.foldr insertField [])
      layoutMatches rawLayout ty
      pure ty
    | _ => none

private def scalarType (raw : Raw) : Option Scalar.Ty := do
  let .scalar ty ← typeOf 17 raw | none
  pure ty

def reference (raw : Raw) : Option Ref := do
  match ← raw.textAt "kind" with
  | "instruction" => pure (.local (← raw.natAt "index"))
  | "unit" => pure (.constant (.scalar .unit))
  | "constant" =>
    let ty ← scalarType (← raw.get "type")
    let n ← (← raw.get "value").integer
    let value ← match ty with
      | .int signed bits => pure (Scalar.Value.int signed bits n)
      | .bool => do require (n == 0 || n == 1); pure (.bool (n == 1))
      | .unit => none
    require value.valid
    pure (.constant (.scalar value))
  | _ => none

private def scalarRef (raw : Raw) : Option Scalar.Ref := do
  match ← reference raw with
  | .local id => pure (.local id)
  | .constant (.scalar value) => pure (.constant value)
  | _ => none

private def binary (inst : Raw) (operation : Ref → Ref → Prim) : Option Prim := do
  pure (operation (← reference (← inst.get "lhs")) (← reference (← inst.get "rhs")))
private def unary (inst : Raw) (operation : Ref → Prim) : Option Prim := do
  pure (operation (← reference (← inst.get "operand")))
private def scalarBinary (inst : Raw) (operation : Scalar.Ref → Scalar.Ref → Scalar.Prim) : Option Prim := do
  pure (.scalar (operation (← scalarRef (← inst.get "lhs")) (← scalarRef (← inst.get "rhs"))))

def primitive (parameters : List Nat) (inst : Raw) (table : List Raw := []) : Option Prim := do
  match ← inst.textAt "tag" with
  | "arg" =>
    let sourceIndex ← inst.natAt "zirParameterIndex"
    pure (.argument (← parameters.findIdx? (· == sourceIndex)))
  | "alloc" =>
    require ((← inst.textAt "allocationKind") == "stack")
    let .pointer true false child ← typeOf 17 (← inst.get "type") | none
    pure (.alloc child)
  | "load" => unary inst .load
  | "store" | "store_safe" => binary inst .store
  | "memcpy" => binary inst .copyBytes
  | "ptr_elem_ptr" => binary inst .elementPointer
  | "ptr_add" => binary inst (.offsetPointer false)
  | "ptr_sub" => binary inst (.offsetPointer true)
  | "slice_elem_ptr" => binary inst .sliceElementPointer
  | "slice" => binary inst (.slice (← typeOf 17 (← inst.get "type")))
  | "slice_len" => unary inst .sliceLen
  | "slice_ptr" => unary inst .slicePtr
  | "array_to_slice" =>
    let operand ← inst.get "operand"
    require ((← operand.textAt "kind") == "instruction")
    let source ← table[← operand.natAt "index"]?
    let .pointer writable false (.array _ child) ← typeOf 17 (← source.get "type") | none
    require ((← typeOf 17 (← inst.get "type")) == .slice writable child)
    unary inst .arrayToSlice
  | "ptr_slice_len_ptr" => unary inst (.pointerField true)
  | "ptr_slice_ptr_ptr" => unary inst (.pointerField false)
  | "ptr_cast" =>
    let target ← typeOf 17 (← inst.get "type")
    match target with
    | .slice .. => unary inst (.sliceCast target)
    | _ => unary inst (.pointerCast target)
  | "not" =>
    require ((← typeOf 17 (← inst.get "type")) == .scalar .bool)
    unary inst .booleanNot
  | "struct_field_ptr" | "struct_field_ptr_index_0" | "struct_field_ptr_index_1" |
      "struct_field_ptr_index_2" | "struct_field_ptr_index_3" =>
    let operand ← inst.get "operand"
    require ((← operand.textAt "kind") == "instruction")
    let source ← table[← operand.natAt "index"]?
    let rawType ← source.get "type"
    let .pointer writable _ owner ← typeOf 17 rawType | none
    let fields ← (← rawType.get "child").listAt "fields"
    let index ← inst.natAt "fieldIndex"
    let tag ← inst.textAt "tag"
    require (tag == "struct_field_ptr" || tag == "struct_field_ptr_index_" ++ toString index)
    let rawField ← fields[index]?
    let offset ← rawField.natAt "offset"
    let child ← typeOf 17 (← rawField.get "type")
    require (fieldType owner offset == some child &&
      (← typeOf 17 (← inst.get "type")) == .pointer writable false child)
    pure (.fieldPointer (← reference operand) offset)
  | "add" => scalarBinary inst (.arithmetic .add .unchecked)
  | "sub" => scalarBinary inst (.arithmetic .sub .unchecked)
  | "mul" => scalarBinary inst (.arithmetic .mul .unchecked)
  | "add_safe" => scalarBinary inst (.arithmetic .add .checked)
  | "sub_safe" => scalarBinary inst (.arithmetic .sub .checked)
  | "mul_safe" => scalarBinary inst (.arithmetic .mul .checked)
  | "add_wrap" => scalarBinary inst (.arithmetic .add .wrapping)
  | "sub_wrap" => scalarBinary inst (.arithmetic .sub .wrapping)
  | "mul_wrap" => scalarBinary inst (.arithmetic .mul .wrapping)
  | "bit_and" => scalarBinary inst .bitAnd
  | "xor" => scalarBinary inst .bitXor
  | "shr" => scalarBinary inst .shiftRight
  | "min" => scalarBinary inst (.extremum false)
  | "max" => scalarBinary inst (.extremum true)
  | "cmp_eq" => scalarBinary inst (.comparison .eq)
  | "cmp_neq" => scalarBinary inst (.comparison .ne)
  | "cmp_lt" => scalarBinary inst (.comparison .lt)
  | "cmp_lte" => scalarBinary inst (.comparison .le)
  | "cmp_gt" => scalarBinary inst (.comparison .gt)
  | "cmp_gte" => scalarBinary inst (.comparison .ge)
  | "int_cast" | "int_cast_safe" | "bit_cast" | "trunc" =>
    let kind ← match ← inst.textAt "tag" with
      | "int_cast" => pure Scalar.Cast.unchecked
      | "int_cast_safe" => pure Scalar.Cast.checked
      | "bit_cast" => pure Scalar.Cast.bitcast
      | "trunc" => pure Scalar.Cast.trunc
      | _ => none
    pure (.scalar (.cast kind (← scalarType (← inst.get "type")) (← scalarRef (← inst.get "operand"))))
  | _ => none

private def guardPrimitive (item : Raw) : Option Prim := do
  require (← item.get "unsupportedReason").isNull
  let upper ← item.get "upperBound"
  let bound ← match ← upper.textAt "kind" with
    | "unboundedPointer" => do
      require (← upper.boolAt "requiresMemoryValidity")
      pure Bound.unbounded
    | "arrayLength" => pure (.array (← upper.natAt "value"))
    | "sliceLength" => pure (.slice (← reference (← upper.get "original")))
    | _ => none
  pure (.checkBounds (← reference (← item.get "start")) (← reference (← item.get "end")) bound)

private def guardIndex (item : Raw) : Option Nat := do
  let anchor ← item.get "anchor"
  require ((← anchor.textAt "kind") == "beforeInstruction" && (← anchor.boolAt "inSupportedBody"))
  anchor.natAt "index"

private def prefixGuards (lift : Prim → P) (count id : Nat) (guards : List Raw) (code : Control.Code Ty P Ref loops) : Option (Control.Code Ty P Ref loops) := do
  let selected := guards.zipIdx |>.filter (fun (item, _) => guardIndex item == some id)
  require (selected.length ≤ 1)
  match selected with
  | [] => pure code
  | [(item, ordinal)] => pure (.bind (count + ordinal) (.scalar .unit) (lift (← guardPrimitive item)) code)
  | _ => none

private def instruction (table : List Raw) (operand : Raw) : Option Raw := do
  require ((← operand.textAt "kind") == "instruction")
  table[← operand.natAt "index"]?

private def copyView (table : List Raw) (tag : String) (operand : Raw) : Raw :=
  ((do
    let inst ← instruction table operand
    require ((← inst.textAt "tag") == tag)
    inst.get "operand") : Option Raw).getD operand

private def copyLength (table : List Raw) (length operand : Raw) : Option (Option Ref) := do
  let lowered ← instruction table operand
  let operandType ← typeOf 17 (← lowered.get "type")
  let origin := match operandType with
    | .pointer _ false (.array ..) => copyView table "ptr_cast" operand
    | _ => operand
  if length.textAt "kind" == some "manyPointer" then
    let .object fields := length | none
    require (fields.length == 2)
    let original ← length.get "operand"
    let .pointer writable true (.scalar (.int false 8)) ←
      typeOf 17 (← (← instruction table original).get "type") | none
    match operandType with
    | .slice .. => require (writable && lowered.textAt "tag" == some "slice")
    | _ => require ((← reference original) == (← reference origin))
    return none
  let view := copyView table "slice_ptr" origin
  let ty ← if (← length.textAt "kind") == "instruction" then do
    let projection ← instruction table length
    require ((← projection.textAt "tag") == "slice_len" &&
      (← reference (← projection.get "operand")) == (← reference view))
    projection.get "type"
    else do
      match operandType with
      | .pointer _ false (.array count _) => require ((← length.natAt "value") == count)
      | _ =>
        let viewType ← typeOf 17 (← (← instruction table view).get "type")
        match viewType with | .slice .. => none | _ => pure ()
      length.get "type"
  require ((← typeOf 17 ty) == .scalar (.int false 64))
  pure (some (← reference length))

private def directCopyPointer (value : Raw) : Bool :=
  value.textAt "tag" == some "arg" || value.textAt "tag" == some "load"

private def copyLengthCheck (table : List Raw) (inst : Raw) : Option (Option Prim) := do
  if let some lengths := inst.get "copyLengths" then
    let .object fields := lengths | none
    require (fields.length == 2)
    match ← copyLength table (← lengths.get "destination") (← inst.get "lhs"),
          ← copyLength table (← lengths.get "source") (← inst.get "rhs") with
    | none, none => none
    | some destination, some source => pure (some (.checkCopyLengths destination source))
    | _, _ => pure none
  else
    let target ← instruction table (← inst.get "lhs")
    let source ← instruction table (← inst.get "rhs")
    let view ← typeOf 17 (← target.get "type")
    let hasSliceLength := match view with | .slice .. => true | _ => false
    require (directCopyPointer source && (hasSliceLength || directCopyPointer target))
    pure none

/-- Fuel bounds parsing, not program execution. Each recursive call consumes a
unit, including sequential operations and nested control. No instruction is
removed based on the liveness of its result. -/
def bodyWith (lift : Prim → P) (operation : Raw → Option P) (loops : Bool)
    (table guards : List Raw) : Nat → List Raw → Option (Control.Code Ty P Ref loops)
  | 0, _ => none
  | _ + 1, [] => none
  | fuel + 1, rawId :: tail => do
    let id ← rawId.natural
    let inst ← table[id]?
    require ((← inst.natAt "index") == id && (← inst.boolAt "payloadVisited"))
    require (inst.get "unsupportedPayload" |>.isNone)
    let tag ← inst.textAt "tag"
    let code ← match tag with
      | "ret" | "ret_safe" => do
        require tail.isEmpty
        pure (.ret (← reference (← inst.get "operand")))
      | "unreach" => do
        require (tail.isEmpty && (← (← inst.get "type").textAt "kind") == "noreturn")
        pure (.bind id (.scalar .unit) (lift .unreachable) (.ret (.constant (.scalar .unit))))
      | "br" => do
        require tail.isEmpty
        pure (.jump (← inst.natAt "target") (← reference (← inst.get "operand")))
      | "repeat" => do
        require tail.isEmpty
        if enabled : loops = true then pure (.repeat enabled (← inst.natAt "target")) else none
      | "loop" => do
        require tail.isEmpty
        if enabled : loops = true then
          pure (.loop enabled id (← bodyWith lift operation loops table guards fuel (← inst.listAt "body")))
        else none
      | "cond_br" => do
        require tail.isEmpty
        pure (.branch (← reference (← inst.get "condition"))
          (← bodyWith lift operation loops table guards fuel (← inst.listAt "thenBody"))
          (← bodyWith lift operation loops table guards fuel (← inst.listAt "elseBody")))
      | "block" =>
        pure (.block id (← typeOf 17 (← inst.get "type"))
          (← bodyWith lift operation loops table guards fuel (← inst.listAt "body"))
          (← bodyWith lift operation loops table guards fuel tail))
      | "dbg_stmt" | "dbg_var_val" | "dbg_var_ptr" | "dbg_arg_inline" => do
        require ((← inst.boolAt "debugOnly") && (← (← inst.get "type").textAt "kind") == "void")
        bodyWith lift operation loops table guards fuel tail
      | "slice_elem_val" | "ptr_elem_val" =>
        let left ← inst.get "lhs"
        require ((← left.textAt "kind") == "instruction")
        let owner ← table[← left.natAt "index"]?
        let ownerType ← typeOf 17 (← owner.get "type")
        let byte := Ty.scalar (.int false 8)
        let writable ← match tag, ownerType with
          | "slice_elem_val", .slice writable child => do require (child == byte); pure writable
          | "ptr_elem_val", .pointer writable true child => do require (child == byte); pure writable
          | _, _ => none
        require ((← typeOf 17 (← inst.get "type")) == byte)
        let temporary := table.length + guards.length + id
        let pointer := if tag == "slice_elem_val" then Prim.sliceElementPointer else Prim.elementPointer
        pure (.bind temporary (.pointer writable false byte) (lift (← binary inst pointer))
          (.bind id byte (lift (.load (.local temporary)))
            (← bodyWith lift operation loops table guards fuel tail)))
      | "memcpy" => do
        let guard ← copyLengthCheck table inst
        let code := .bind id (← typeOf 17 (← inst.get "type")) (← operation inst)
          (← bodyWith lift operation loops table guards fuel tail)
        match guard with
        | none => pure code
        | some check => pure (.bind (2 * table.length + guards.length + id) (.scalar .unit) (lift check) code)
      | _ => pure (.bind id (← typeOf 17 (← inst.get "type")) (← operation inst)
          (← bodyWith lift operation loops table guards fuel tail))
    prefixGuards lift table.length id guards code

def body (loops : Bool) (parameters : List Nat) (table guards : List Raw) :=
  bodyWith id (fun inst => primitive parameters inst table) loops table guards

inductive SpecializationPolicy where
  | standalone
  | directCall
  deriving BEq

/-- Preserve source parameter indices after specialization. Direct calls can
also bind concrete runtime anytype parameters. Earlier captures use "runtime"
for both parameter shapes; native admission checks the original declaration. -/
def parameterMapping (raw signature : Raw) (runtimeCount : Nat)
    (policy : SpecializationPolicy := .standalone) : Option (List Nat) := do
  if !(← signature.boolAt "genericInstance") then
    require (raw.get "specialization" |>.isNone)
    pure (List.range runtimeCount)
  else
    let spec ← raw.get "specialization"
    require ((← spec.textAt "schema") == "oksolc.generic-instance.v1" &&
      (← spec.natAt "sourceNoaliasBits") == 0)
    let owner ← spec.get "owner"
    require ((← owner.textAt "sourceFile") == (← raw.textAt "sourceFile") &&
      (← owner.textAt "sourceSha256") == (← raw.textAt "sourceSha256") &&
      (← raw.textAt "name").startsWith ((← owner.textAt "name") ++ "__func_"))
    let args ← spec.listAt "arguments"
    let bits ← spec.natAt "sourceComptimeBits"
    require ((← spec.natAt "sourceParameterCount") == args.length && args.length ≤ 32 &&
      bits < 2 ^ args.length && (bits > 0 || (policy == .directCall && runtimeCount > 0)))
    let (count, indices) ← args.zipIdx.foldlM (fun (count, indices) (arg, index) => do
      let kind ← arg.textAt "kind"
      match kind with
      | "runtime" | "runtimeAnytype" =>
        require ((kind == "runtime" || policy == .directCall) && !(bits.testBit index) && (← arg.natAt "runtimeIndex") == count)
        pure (count + 1, indices ++ [index])
      | "type" =>
        require (bits.testBit index)
        let _ ← typeOf 17 (← arg.get "value")
        pure (count, indices)
      | _ => none) (0, [])
    require (count == runtimeCount)
    pure indices

/-- Interpretation for the declared captured-memory subset. Source validity
coverage is deliberately still incomplete; the encoded guards are executed. -/
structure Input where
  parameters : List Ty
  returnType : Ty
  mapping : List Nat
  guards : List Raw
  table : List Raw
  root : List Raw

def checkCopyCoverage (raw validity : Raw) (table : List Raw) : Option Unit := do
  let sourceCopy := (← raw.listAt "sourceOperationTags").any fun tag =>
    tag.text == some "memcpy" || tag.text == some "memmove"
  match validity.get "copyLengthsAnchored" with
  | none => require (!sourceCopy)
  | some flag =>
    require (flag.flag == some true && table.all fun inst =>
      inst.textAt "tag" != some "memcpy" || inst.boolAt "payloadVisited" != some true ||
        (inst.get "copyLengths").isSome)

def prepare (raw : Raw) (policy : SpecializationPolicy := .standalone) : Option Input := do
  require ((← raw.textAt "schema") == "oksolc.fresh-air.v3" &&
    (← raw.textAt "capturePoint") == "after-sema-before-legalize" &&
    (← raw.textAt "bodyTraversal") == "supported-structured-containers-only" &&
    !(← raw.boolAt "sourceValidityConditionsPreserved"))
  let configuration ← raw.get "configuration"
  require (Target.acceptsMemory (← configuration.textAt "arch") (← configuration.textAt "os")
    (← configuration.natAt "pointerBits") (← configuration.textAt "endianness") &&
    (← configuration.textAt "optimize") == "ReleaseFast" && (← configuration.boolAt "useLlvm") &&
    !(← configuration.boolAt "isTest"))
  let signature ← raw.get "signature"
  require (!(← signature.boolAt "varArgs") &&
    (← signature.natAt "noaliasBits") == 0)
  let parameters ← (← signature.listAt "parameters").mapM (typeOf 17)
  let mapping ← parameterMapping raw signature parameters.length policy
  let returnType ← typeOf 17 (← signature.get "returnType")
  let validity ← raw.get "sourceValidity"
  require ((← validity.textAt "schema") == "oksolc.source-validity.v1" &&
    (← validity.textAt "coverage") == "runtime-slice-results" && !(← validity.boolAt "complete"))
  let guards ← validity.listAt "slices"
  let table ← raw.listAt "instructions"
  require (table.length > 0 && table.length ≤ 512)
  checkCopyCoverage raw validity table
  pure ⟨parameters, returnType, mapping, guards, table, ← raw.listAt "body"⟩

def decode (loops : Bool) (raw : Raw) : Option (Program loops) := do
  let input ← prepare raw
  let code ← body loops input.mapping input.table input.guards 1024 input.root
  pure ⟨input.parameters, input.returnType, code⟩

/-- Substitute a checked correspondence into any model execution theorem.
The `decoded` premise is about the inert input, not a claimed source hash. -/
theorem interpretation_eq (raw : Raw) (program : Program loops)
    (certificate : decode loops raw = some program) (decoded : decode loops raw = some other) :
    other = program := Option.some.inj (decoded.symm.trans certificate)

end Compiler.ZigAir.Captured
