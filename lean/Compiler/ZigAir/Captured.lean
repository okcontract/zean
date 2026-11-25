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

/-- The certificate producer lifts objects in sorted key order. Comparing that
representation is reducible in the kernel, including nested declarations. -/
def Raw.equal : Nat → Raw → Raw → Bool
  | 0, _, _ => false
  | _ + 1, .null, .null => true
  | _ + 1, .boolean a, .boolean b => a == b
  | _ + 1, .number a, .number b => a == b
  | _ + 1, .string a, .string b => a == b
  | fuel + 1, .array a, .array b =>
    a.length == b.length && (a.zip b).all (fun (left, right) => left.equal fuel right)
  | fuel + 1, .object a, .object b =>
    a.length == b.length && (a.zip b).all (fun ((leftKey, leftValue), (rightKey, rightValue)) =>
      leftKey == rightKey && leftValue.equal fuel rightValue)
  | _, _, _ => false

private def Raw.usesInstruction (index : Nat) : Nat → Raw → Bool
  | 0, _ => true
  | fuel + 1, .array values => values.any (Raw.usesInstruction index fuel)
  | fuel + 1, raw@(.object properties) =>
    (raw.textAt "kind" == some "instruction" && raw.natAt "index" == some index) ||
      properties.any (fun (_, value) => value.usesInstruction index fuel)
  | _ + 1, _ => false

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

private def identityName (raw : Raw) : Option String := do
  let identity ← raw.get "identity"
  let name ← identity.textAt "name"
  let hash ← identity.textAt "sourceSha256"
  require (!name.isEmpty && !(← identity.textAt "sourceFile").isEmpty && hash.length == 64 &&
    hash.toList.all (fun ch => ch.isDigit || ('a' ≤ ch && ch ≤ 'f')))
  pure name

private def enumDeclaration (raw : Raw) : Option Scalar.EnumDecl := do
  let name ← identityName raw
  let identity ← raw.get "identity"
  let backing ← raw.get "backingType"
  let bits ← backing.natAt "bits"
  require ((← backing.textAt "kind") == "int" && (← backing.textAt "signedness") == "unsigned" &&
    0 < bits && bits ≤ 64 && !(← raw.boolAt "nonexhaustive"))
  let fields ← raw.listAt "fields"
  require (!fields.isEmpty && fields.length ≤ 256)
  let tags ← fields.zipIdx |>.mapM fun (field, index) => do
    let name ← field.textAt "name"
    let value ← field.natAt "value"
    require ((← field.natAt "index") == index && !name.isEmpty && value < 2 ^ bits)
    pure (name, value)
  require (decide (tags.Pairwise fun left right => left.1 ≠ right.1 ∧ left.2 ≠ right.2))
  pure ⟨name, ← identity.textAt "sourceFile", ← identity.textAt "sourceSha256", bits, tags⟩

/-- Inactive enum storage supplies extent and alignment to its enclosing owner. -/
private def opaqueEnum (raw : Raw) : Option Ty := do
  let decl ← enumDeclaration raw
  let size := if decl.width ≤ 8 then 1 else if decl.width ≤ 16 then 2 else if decl.width ≤ 32 then 4 else 8
  let type := Ty.record ("enum:" ++ decl.name) ⟨size, size⟩
  layoutMatches (← raw.get "layout") type
  pure type

private def enumText (value : String) : Bool :=
  value.utf8ByteSize ≤ 1024 && value.toList.all (fun char => 32 ≤ char.toNat && char.toNat != 127)

private def finiteEnum (raw : Raw) : Option Ty := do
  let .object properties := raw | none
  require (properties.length == 6)
  let .object identity ← raw.get "identity" | none
  let .object backing ← raw.get "backingType" | none
  let abi@(.object layout) ← raw.get "layout" | none
  require (identity.length == 3 && backing.length == 3 && layout.length == 3)
  let fields ← raw.listAt "fields"
  require (fields.length ≤ 64 && fields.all (fun field => match field with
    | .object properties => properties.length == 3 | _ => false))
  let decl ← enumDeclaration raw
  require (enumText decl.name && enumText decl.sourceFile && decl.tags.all (enumText ∘ Prod.fst))
  let type := Ty.scalar (.enumeration decl)
  layoutMatches abi type
  pure type

/-- Zero-storage declarations have no heap fields. Only validated automatic
structures of zero-storage fields and exhaustive single-tag u0 enums qualify. -/
private def zeroStorage : Nat → Raw → Option Unit
  | 0, _ => none
  | fuel + 1, raw => do
    let _ ← identityName raw
    let layout ← raw.get "layout"
    require ((← layout.textAt "kind") == "abi" && (← layout.natAt "bytes") == 0 &&
      (← layout.natAt "alignment") == 1)
    let fields ← raw.listAt "fields"
    match ← raw.textAt "kind" with
    | "enum" =>
      let [field] := fields | none
      let backing ← raw.get "backingType"
      require ((← backing.textAt "kind") == "int" &&
        (← backing.textAt "signedness") == "unsigned" && (← backing.natAt "bits") == 0 &&
        !(← raw.boolAt "nonexhaustive") && (← field.natAt "index") == 0 &&
        (← field.natAt "value") == 0 && !(← field.textAt "name").isEmpty)
    | "struct" =>
      require ((← raw.textAt "containerLayout") == "auto" && !fields.isEmpty && fields.length ≤ 64)
      let names ← fields.mapM (·.textAt "name")
      require (decide names.Nodup)
      for (field, index) in fields.zipIdx do
        require ((← field.natAt "index") == index && (← field.natAt "offset") == 0 &&
          (← field.get "explicitAlignment").isNull && !(← field.textAt "name").isEmpty)
        zeroStorage fuel (← field.get "type")
    | _ => none

private def pointerType (raw : Raw) (child : Ty) : Option Ty := do
  require ((← raw.textAt "kind") == "pointer")
  let flags ← raw.get "flags"
  let size ← flags.textAt "size"
  require (["one", "many", "slice"].contains size)
  let writable := !(← flags.boolAt "isConst")
  require (!(← flags.boolAt "isVolatile") && !(← flags.boolAt "allowZero") &&
    (← flags.textAt "addressSpace") == "generic" && (← flags.get "vectorIndex").isNull &&
    (← flags.get "alignment").isNull && (← raw.get "sentinel").isNull &&
    (← flags.natAt "hostSizeBytes") == 0 && (← flags.natAt "bitOffset") == 0)
  let ty := if size == "slice" then Ty.slice writable child else Ty.pointer writable (size == "many") child
  layoutMatches (← raw.get "layout") ty
  layoutMatches (← raw.get "pointeeLayout") child
  pure ty

private def errorNames (raw : Raw) : Option (List String) := do
  let .object fields := raw | none
  require (fields.length == 2 && (← raw.textAt "kind") == "errorSet")
  let names ← (← raw.listAt "names").mapM Raw.text
  require (names.length ≤ 64 && names.all (fun name => !name.isEmpty && name.utf8ByteSize ≤ 128 &&
    name.toList.all (fun char => 32 ≤ char.toNat && char.toNat != 127)) && decide names.Nodup)
  pure names

def typeOf : Nat → Raw → Option Ty
  | 0, _ => none
  | fuel + 1, raw => do
    match ← raw.textAt "kind" with
    | "void" => pure (.scalar .unit)
    | "bool" => pure (.scalar .bool)
    | "errorSet" => pure (.errorValue .tag (← errorNames raw))
    | "errorStatus" => do
      let .object fields := raw | none
      require (fields.length == 2)
      pure (.errorValue .result (← errorNames (← raw.get "errors")))
    | "errorScalar" =>
      let .object fields := raw | none
      let child@(.object childFields) ← raw.get "child" | none
      let .scalar (type@(.int _ bits)) ← typeOf fuel child | none
      require (fields.length == 3 && childFields.length == 3 && 0 < bits && bits ≤ 64)
      pure (.errorScalar type (← errorNames (← raw.get "errors")))
    | "int" =>
      let bits ← raw.natAt "bits"
      let signed ← raw.textAt "signedness"
      require (bits ≤ 512 && (signed == "signed" || signed == "unsigned"))
      pure (.scalar (.int (signed == "signed") bits))
    | "optionalScalar" =>
      let .object fields := raw | none
      let child@(.object childFields) ← raw.get "child" | none
      let abi@(.object layoutFields) ← raw.get "layout" | none
      require (fields.length == 3 && childFields.length == 3 && layoutFields.length == 3 &&
        (← typeOf fuel child) == .scalar (.int false 8))
      let type := Ty.optionalScalar (.int false 8)
      layoutMatches abi type
      pure type
    | "pointer" => pointerType raw (← typeOf fuel (← raw.get "child"))
    | "array" =>
      require (← raw.get "sentinel").isNull
      let ty := Ty.array (← raw.natAt "length") (← typeOf fuel (← raw.get "child"))
      layoutMatches (← raw.get "layout") ty
      pure ty
    | "enum" => opaqueEnum raw
    | "finiteEnum" => finiteEnum raw
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
      require (layout.bytes > 0 && !rawFields.isEmpty && rawFields.length ≤ 64)
      let names ← rawFields.mapM (·.textAt "name")
      require (decide names.Nodup)
      let fields ← rawFields.zipIdx |>.mapM fun (rawField, index) => do
        require ((← rawField.natAt "index") == index && (← rawField.get "explicitAlignment").isNull &&
          !(← rawField.textAt "name").isEmpty)
        let offset ← rawField.natAt "offset"
        let captured ← rawField.get "type"
        if (captured.get "layout" >>= (·.natAt "bytes")) == some 0 then
          require (offset ≤ layout.bytes)
          zeroStorage fuel captured
          pure none
        else
          let child ← typeOf fuel captured
          let field := match child with | .scalar scalar => Field.scalar scalar | _ => Field.object child
          pure (some (offset, field))
      let stored := fields.filterMap id
      require (!stored.isEmpty)
      let ty := Ty.aggregate name layout (stored.foldr insertField [])
      layoutMatches rawLayout ty
      pure ty
    | _ => none

private def scalarType (raw : Raw) : Option Scalar.Ty := do
  let .scalar ty ← typeOf 17 raw | none
  pure ty

private def scalarLiteral (raw : Raw) : Option Scalar.Value := do
  let ty ← scalarType (← raw.get "type")
  let n ← (← raw.get "value").integer
  let value ← match ty with
    | .int signed bits => pure (Scalar.Value.int signed bits n)
    | .bool => do require (n == 0 || n == 1); pure (.bool (n == 1))
    | .unit | .enumeration _ => none
  require value.valid
  pure value

def reference (raw : Raw) : Option Ref := do
  let kind ← raw.textAt "kind"
  match kind with
  | "instruction" => pure (.local (← raw.natAt "index"))
  | "unit" => pure (.constant (.scalar .unit))
  | "enumTag" => do
    let .object fields := raw | none
    require (fields.length == 3)
    let .enumeration decl ← scalarType (← raw.get "type") | none
    let tag ← raw.natAt "value"
    require (decl.hasTag tag)
    pure (.constant (.scalar (.enumTag decl tag)))
  | "errorValue" | "errorStatus" => do
    let .object fields := raw | none
    let .errorValue status allowed ← typeOf 17 (← raw.get "type") | none
    require (fields.length == 3 && ((kind == "errorStatus") == (status == .result)))
    let name ← raw.get "name"
    let named ← if name.isNull then pure none else pure (some (← name.text))
    let value := Value.errorValue status allowed named
    require value.valid
    pure (.constant value)
  | "errorScalar" => do
    let .object fields := raw | none
    let .errorScalar child allowed ← typeOf 17 (← raw.get "type") | none
    require (fields.length == 4)
    let name ← raw.get "name"
    let payload ← raw.get "payload"
    let result ← if name.isNull then do
      let .object payloadFields := payload | none
      let .object payloadType ← payload.get "type" | none
      require (payloadFields.length == 3 && payloadType.length == 3 &&
        (← payload.textAt "kind") == "constant")
      pure (.inr (← scalarLiteral payload))
    else do
      require payload.isNull
      pure (.inl (← name.text))
    let value := Value.errorScalar child allowed result
    require value.valid
    pure (.constant value)
  | "optionalValue" => do
    let .object fields := raw | none
    let .optionalScalar child ← typeOf 17 (← raw.get "type") | none
    require (fields.length == 3)
    let payload ← raw.get "payload"
    let decoded ← if payload.isNull then pure none else do
      let .object payloadFields := payload | none
      let .object payloadType ← payload.get "type" | none
      require (payloadFields.length == 3 && payloadType.length == 3 &&
        (← payload.textAt "kind") == "constant")
      let value ← scalarLiteral payload
      require (value.type == child)
      pure (some value)
    pure (.constant (.optionalScalar child decoded))
  | "constant" => pure (.constant (.scalar (← scalarLiteral raw)))
  | _ => none

private def singletonValue : Nat → Raw → Raw → Option Unit
  | 0, _, _ => none
  | fuel + 1, declared, value => do
    let .object properties := value | none
    require (properties.length == 3 && Raw.equal 128 (← value.get "type") declared)
    match ← declared.textAt "kind" with
    | "enum" =>
      require ((← value.textAt "kind") == "enumTag" && (← value.natAt "value") == 0)
    | "struct" =>
      require ((← value.textAt "kind") == "aggregate")
      let fields ← declared.listAt "fields"
      let members ← value.listAt "fields"
      require (members.length == fields.length)
      for (field, member) in fields.zip members do
        singletonValue fuel (← field.get "type") member
    | _ => none

/-- A removed argument must still be a defined inhabitant of the exact
singleton declaration. Remaining references keep their original order. -/
def callArguments (inst : Raw) (parameters : List Raw) : Option (List Ref) := do
  let raw ← inst.listAt "arguments"
  require (raw.length == parameters.length)
  let decoded ← (parameters.zip raw).mapM fun (parameter, value) => do
    if (zeroStorage 17 parameter).isSome then
      singletonValue 17 parameter value
      pure none
    else pure (some (← reference value))
  pure (decoded.filterMap id)

private def scalarRef (raw : Raw) : Option Scalar.Ref := do
  match ← reference raw with
  | .local id => pure (.local id)
  | .constant (.scalar value) => pure (.constant value)
  | _ => none

private def instruction (table : List Raw) (operand : Raw) : Option Raw := do
  require ((← operand.textAt "kind") == "instruction")
  table[← operand.natAt "index"]?

private def referenceTypeRaw (table : List Raw) (operand : Raw) : Option Raw := do
  let typed ← if (← operand.textAt "kind") == "instruction" then instruction table operand
    else some operand
  typed.get "type"

private def referenceType (table : List Raw) (operand : Raw) : Option Ty := do
  if (← operand.textAt "kind") == "unit" then return .scalar .unit
  typeOf 17 (← referenceTypeRaw table operand)

private def enumOperand (table : List Raw) (operand : Raw) : Bool :=
  (referenceTypeRaw table operand >>= (·.textAt "kind")) == some "finiteEnum"

private def binary (inst : Raw) (operation : Ref → Ref → Prim) : Option Prim := do
  pure (operation (← reference (← inst.get "lhs")) (← reference (← inst.get "rhs")))
private def unary (inst : Raw) (operation : Ref → Prim) : Option Prim := do
  pure (operation (← reference (← inst.get "operand")))
private def scalarBinary (table : List Raw) (inst : Raw)
    (operation : Scalar.Ref → Scalar.Ref → Scalar.Prim) : Option Prim := do
  let left ← inst.get "lhs"
  let right ← inst.get "rhs"
  require (!enumOperand table left && !enumOperand table right &&
    (← (← inst.get "type").textAt "kind") != "finiteEnum")
  pure (.scalar (operation (← scalarRef left) (← scalarRef right)))

private def compare (table : List Raw) (inst : Raw) (op : Scalar.Comparison) : Option Prim := do
  let left ← inst.get "lhs"
  let right ← inst.get "rhs"
  if enumOperand table left || enumOperand table right then
    let .scalar (.enumeration decl) ← referenceType table left | none
    require ((op == .eq || op == .ne) && referenceType table right == some (.scalar (.enumeration decl)) &&
      (← typeOf 17 (← inst.get "type")) == .scalar .bool)
    pure (.scalar (.compareEnum (op == .eq) (← scalarRef left) (← scalarRef right)))
  else scalarBinary table inst (.comparison op)

private def byteTransfer (table : List Raw) (inst : Raw) (operation : Ref → Ref → Prim) : Option Prim := do
  let destination ← referenceType table (← inst.get "lhs")
  let source ← referenceType table (← inst.get "rhs")
  let byte := Ty.scalar (.int false 8)
  let writable := match destination with
    | .slice true child | .pointer true false (.array _ child) => child == byte
    | _ => false
  let readable := match source with
    | .pointer _ true child | .pointer _ false (.array _ child) => child == byte
    | _ => false
  require (writable && readable && (← typeOf 17 (← inst.get "type")) == .scalar .unit)
  binary inst operation

private def undefinedFill (table : List Raw) (inst : Raw) : Option Prim := do
  let destination ← inst.get "lhs"
  let .slice true (.scalar element) ← referenceType table destination | none
  match element with | .enumeration _ => none | _ => pure ()
  let element := Ty.scalar element
  let layout ← element.layout
  let fill@(.object fields) ← inst.get "rhs" | none
  require (fields.length == 2 && (← fill.textAt "kind") == "undefined" &&
    (← typeOf 17 (← fill.get "type")) == element && layout.bytes > 0 &&
    (← typeOf 17 (← inst.get "type")) == .scalar .unit)
  pure (.invalidateSlice (← reference destination))

private structure FieldProjection where
  reference : Ref
  owner : Ty
  writable : Bool
  many : Bool
  offset : Nat
  declared : Raw

private def fieldProjection (table : List Raw) (inst : Raw) : Option FieldProjection := do
  let operand ← inst.get "operand"
  let source ← instruction table operand
  let rawType ← source.get "type"
  let .pointer writable many owner ← typeOf 17 rawType | none
  let fields ← (← rawType.get "child").listAt "fields"
  let index ← inst.natAt "fieldIndex"
  let tag ← inst.textAt "tag"
  require (tag == "struct_field_ptr" || tag == "struct_field_ptr_index_" ++ toString index)
  let field ← fields[index]?
  pure ⟨← reference operand, owner, writable, many, ← field.natAt "offset", ← field.get "type"⟩

private def zeroFieldProjection (table : List Raw) (inst result : Raw) : Option Prim := do
  let field ← fieldProjection table inst
  let layout ← field.owner.layout
  require (!field.many && field.offset ≤ layout.bytes)
  zeroStorage 17 field.declared
  require (Raw.equal 128 (← result.get "child") field.declared &&
    (← pointerType result (.scalar .unit)) == .pointer field.writable false (.scalar .unit))
  pure (.checkZeroField field.reference field.offset)

private def errorUnion : Ty → Option (Scalar.Ty × List String)
  | .errorValue .result allowed => some (.unit, allowed)
  | .errorScalar child allowed => some (child, allowed)
  | _ => none

private def errorOperation (table : List Raw) (inst : Raw) (tag : String) : Option Prim := do
  let operand ← inst.get "operand"
  let reference ← reference operand
  let input ← referenceType table operand
  let result ← typeOf 17 (← inst.get "type")
  if tag == "wrap_errunion_payload" || tag == "wrap_errunion_err" then
    let (child, allowed) ← errorUnion result
    if tag == "wrap_errunion_payload" then
      require (input == .scalar child)
    else
      let .errorValue .tag source := input | none
      require (source.all allowed.contains)
    pure (if child == .unit then .wrapError allowed reference else .wrapScalarError child allowed reference)
  else
    let (child, allowed) ← errorUnion input
    if tag == "is_err" || tag == "is_non_err" then
      require (result == .scalar .bool)
      pure (.testError (tag == "is_non_err") reference)
    else
      let payload := tag == "unwrap_errunion_payload"
      require (result == if payload then .scalar child else .errorValue .tag allowed)
      pure (.unwrapError payload reference)

private def optionalOperation (table : List Raw) (inst : Raw) (tag : String) : Option Prim := do
  let .object fields := inst | none
  require (fields.length == 5)
  let operand ← inst.get "operand"
  let ref ← reference operand
  let input ← referenceType table operand
  let result ← typeOf 17 (← inst.get "type")
  if tag == "wrap_optional" then
    let .optionalScalar child := result | none
    require (input == .scalar child)
    pure (.wrapOptional ref)
  else
    let .optionalScalar child := input | none
    if tag == "optional_payload" then
      require (result == .scalar child)
      pure (.optionalPayload ref)
    else
      require (result == .scalar .bool)
      pure (.testOptional (tag == "is_non_null") ref)

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
  | "memcpy" => byteTransfer table inst .copyBytes
  | "memmove" => byteTransfer table inst .moveBytes
  | "memset" => undefinedFill table inst
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
  | "is_err" | "is_non_err" | "unwrap_errunion_payload" | "unwrap_errunion_err" |
      "wrap_errunion_payload" | "wrap_errunion_err" => errorOperation table inst (← inst.textAt "tag")
  | "is_null" | "is_non_null" | "optional_payload" | "wrap_optional" =>
    optionalOperation table inst (← inst.textAt "tag")
  | "struct_field_ptr" | "struct_field_ptr_index_0" | "struct_field_ptr_index_1" |
      "struct_field_ptr_index_2" | "struct_field_ptr_index_3" =>
    let field ← fieldProjection table inst
    let child ← typeOf 17 field.declared
    require (fieldType field.owner field.offset == some child &&
      (← typeOf 17 (← inst.get "type")) == .pointer field.writable false child)
    pure (.fieldPointer field.reference field.offset)
  | "add" => scalarBinary table inst (.arithmetic .add .unchecked)
  | "sub" => scalarBinary table inst (.arithmetic .sub .unchecked)
  | "mul" => scalarBinary table inst (.arithmetic .mul .unchecked)
  | "add_safe" => scalarBinary table inst (.arithmetic .add .checked)
  | "sub_safe" => scalarBinary table inst (.arithmetic .sub .checked)
  | "mul_safe" => scalarBinary table inst (.arithmetic .mul .checked)
  | "add_wrap" => scalarBinary table inst (.arithmetic .add .wrapping)
  | "sub_wrap" => scalarBinary table inst (.arithmetic .sub .wrapping)
  | "mul_wrap" => scalarBinary table inst (.arithmetic .mul .wrapping)
  | "div_trunc" =>
    let .scalar (.int false width) ← typeOf 17 (← inst.get "type") | none
    let type := Ty.scalar (.int false width)
    require (width > 0 && referenceType table (← inst.get "lhs") == some type &&
      referenceType table (← inst.get "rhs") == some type)
    scalarBinary table inst .divideUnsigned
  | "bit_and" => scalarBinary table inst .bitAnd
  | "bit_or" => scalarBinary table inst .bitOr
  | "xor" => scalarBinary table inst .bitXor
  | "shr" => scalarBinary table inst .shiftRight
  | "shl" => scalarBinary table inst .shiftLeft
  | "min" => scalarBinary table inst (.extremum false)
  | "max" => scalarBinary table inst (.extremum true)
  | "cmp_eq" => compare table inst .eq
  | "cmp_neq" => compare table inst .ne
  | "cmp_lt" => compare table inst .lt
  | "cmp_lte" => compare table inst .le
  | "cmp_gt" => compare table inst .gt
  | "cmp_gte" => compare table inst .ge
  | "int_cast" | "int_cast_safe" | "bit_cast" | "trunc" =>
    let kind ← match ← inst.textAt "tag" with
      | "int_cast" => pure Scalar.Cast.unchecked
      | "int_cast_safe" => pure Scalar.Cast.checked
      | "bit_cast" => pure Scalar.Cast.bitcast
      | "trunc" => pure Scalar.Cast.trunc
      | _ => none
    let destination ← scalarType (← inst.get "type")
    let operand ← inst.get "operand"
    require (!enumOperand table operand && (match destination with | .enumeration _ => false | _ => true))
    let ref ← scalarRef operand
    if kind == .bitcast && destination == .int false 1 &&
        referenceType table operand == some (.scalar .bool) then
      pure (.scalar (.boolToInt ref))
    else pure (.scalar (.cast kind destination ref))
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

private def copyView (table : List Raw) (tag : String) (operand : Raw) : Raw :=
  ((do
    let inst ← instruction table operand
    require ((← inst.textAt "tag") == tag)
    inst.get "operand") : Option Raw).getD operand

private def copyLength (table : List Raw) (length operand : Raw) (sourceLength : Option Raw) : Option (Option Ref) := do
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
    | .slice .. =>
      let borrowed ← sourceLength
      require (writable && lowered.textAt "tag" == some "slice" &&
        (← reference (← lowered.get "lhs")) == (← reference original) &&
        (← reference (← lowered.get "rhs")) == (← reference borrowed))
    | _ =>
      require ((← reference original) == (← reference origin))
      if let some borrowed := sourceLength then
        let .pointer _ false (.array count _) := operandType | none
        require (borrowed.textAt "kind" == some "constant" && (← borrowed.natAt "value") == count)
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
    let sourceLength ← lengths.get "source"
    let source ← copyLength table sourceLength (← inst.get "rhs") none
    match ← copyLength table (← lengths.get "destination") (← inst.get "lhs") (some sourceLength), source with
    | none, none => none
    | some destination, some source => pure (some (.checkCopyLengths destination source))
    | _, _ => pure none
  else
    require (inst.textAt "tag" == some "memcpy")
    let target ← instruction table (← inst.get "lhs")
    let source ← instruction table (← inst.get "rhs")
    let view ← typeOf 17 (← target.get "type")
    let hasSliceLength := match view with | .slice .. => true | _ => false
    require (directCopyPointer source && (hasSliceLength || directCopyPointer target))
    pure none

private def switchBound (type : Scalar.Ty) (raw : Raw) : Option Int := do
  let .constant value ← scalarRef raw | none
  require (type == value.type)
  match value with
  | .int _ _ number => pure number
  | .enumTag _ tag => pure tag
  | _ => none

private def switchArms (type : Scalar.Ty) (inst : Raw) :
    Option (List (List (Int × Int) × List Raw)) := do
  let arms ← inst.listAt "cases"
  require (!arms.isEmpty && arms.length ≤ 256)
  let decoded ← arms.mapM fun arm => do
    let rawRanges ← arm.listAt "ranges"
    require (!rawRanges.isEmpty && rawRanges.length ≤ 256)
    let ranges ← rawRanges.mapM fun raw => do
      let [lower, upper] ← raw.list | none
      let low ← switchBound type lower
      let high ← switchBound type upper
      require (match type with | .enumeration _ => low == high | _ => decide (low ≤ high))
      pure (low, high)
    pure (ranges, ← arm.listAt "body")
  let allRanges := decoded.flatMap Prod.fst
  require (allRanges.length ≤ 256 &&
    decide (allRanges.Pairwise fun left right => left.2 < right.1 ∨ right.2 < left.1))
  pure decoded

/-- An error arm may use its own structure while all outer continuations
remain out of scope. Its only exits cross the ordinary return/fault boundary. -/
private def localDestinations (code : Control.Code Ty P Ref loops) (blocks repeats : List Nat) : Bool :=
  match code with
  | .bind _ _ _ rest => localDestinations rest blocks repeats
  | .branch _ yes no => localDestinations yes blocks repeats && localDestinations no blocks repeats
  | .block id _ body rest => localDestinations body (id :: blocks) repeats && localDestinations rest blocks repeats
  | .loop _ id body => localDestinations body blocks (id :: repeats)
  | .jump target _ => blocks.contains target
  | .repeat _ target => repeats.contains target
  | .ret _ => true

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
      | "switch_br" => do
        require (tail.isEmpty && (← (← inst.get "type").textAt "kind") == "noreturn")
        let operand ← inst.get "operand"
        let .scalar type ← referenceType table operand | none
        require (match type with | .int _ bits => decide (bits > 0) | .enumeration _ => true | _ => false)
        let ref ← scalarRef operand
        let arms ← switchArms type inst
        let defaultBody ← inst.listAt "elseBody"
        let fallback ← if defaultBody.isEmpty then do
            let .enumeration decl := type | none
            require ((arms.flatMap Prod.fst).length == decl.tags.length)
            pure (.bind id (.scalar .unit) (lift .unreachable) (.ret (.constant (.scalar .unit))))
          else bodyWith lift operation loops table guards fuel defaultBody
        let decoded ← arms.zipIdx.mapM fun ((ranges, body), ordinal) => do
          let register := 3 * table.length + guards.length + id * 256 + ordinal
          let selected ← bodyWith lift operation loops table guards fuel body
          pure (register, ranges, selected)
        pure (decoded.foldr (fun (register, ranges, selected) rest =>
          let condition := match type with
            | .enumeration _ => Scalar.Prim.enumInTags ref (ranges.map (fun range => range.1.toNat))
            | _ => Scalar.Prim.inRanges ref ranges
          .bind register (.scalar .bool) (lift (.scalar condition)) (.branch (.local register) selected rest)) fallback)
      | "try" | "try_cold" => do
        let operand ← inst.get "operand"
        let (child, _) ← errorUnion (← referenceType table operand)
        require ((← typeOf 17 (← inst.get "type")) == .scalar child)
        let ref ← reference operand
        let handler ← bodyWith lift operation loops table guards fuel (← inst.listAt "errorBody")
        require (localDestinations handler [] [])
        let continuation ← bodyWith lift operation loops table guards fuel tail
        let condition := 2 * table.length + guards.length + id
        pure (.bind condition (.scalar .bool) (lift (.testError false ref))
          (.branch (.local condition) handler
            (.bind id (.scalar child) (lift (.unwrapError true ref)) continuation)))
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
      | "memcpy" | "memmove" => do
        let guard ← copyLengthCheck table inst
        let code := .bind id (← typeOf 17 (← inst.get "type")) (← operation inst)
          (← bodyWith lift operation loops table guards fuel tail)
        match guard with
        | none => pure code
        | some check => pure (.bind (2 * table.length + guards.length + id) (.scalar .unit) (lift check) code)
      | "struct_field_ptr" | "struct_field_ptr_index_0" | "struct_field_ptr_index_1" |
          "struct_field_ptr_index_2" | "struct_field_ptr_index_3" => do
        let result ← inst.get "type"
        let next ← bodyWith lift operation loops table guards fuel tail
        if let some ty := typeOf 17 result then
          pure (.bind id ty (← operation inst) next)
        else
          require (!table.any (Raw.usesInstruction id 128) && !guards.any (Raw.usesInstruction id 128))
          pure (.bind id (.scalar .unit) (lift (← zeroFieldProjection table inst result)) next)
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
also bind concrete runtime anytype parameters and named comptime callbacks.
Native admission checks the original declaration. -/
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
      | "value" =>
        require (policy == .directCall && bits.testBit index)
        let callback ← arg.get "value"
        require ((← callback.textAt "kind") == "function")
        let _ ← identityName callback
        pure (count, indices)
      | _ => none) (0, [])
    require (count == runtimeCount)
    pure indices

/-- Interpretation for the declared captured-memory subset. Source validity
coverage is deliberately still incomplete; the encoded guards are executed. -/
structure Input where
  parameters : List Ty
  parameterTypes : List Raw
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
      (inst.textAt "tag" != some "memcpy" && inst.textAt "tag" != some "memmove") ||
        inst.boolAt "payloadVisited" != some true ||
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
  let parameterTypes ← signature.listAt "parameters"
  let sourceParameters ← parameterMapping raw signature parameterTypes.length policy
  let stored := (parameterTypes.zip sourceParameters).filter fun (parameter, _) =>
    policy != .directCall || (zeroStorage 17 parameter).isNone
  let parameters ← stored.mapM (fun (parameter, _) => typeOf 17 parameter)
  let mapping := stored.map Prod.snd
  let returnType ← typeOf 17 (← signature.get "returnType")
  let validity ← raw.get "sourceValidity"
  require ((← validity.textAt "schema") == "oksolc.source-validity.v1" &&
    (← validity.textAt "coverage") == "runtime-slice-results" && !(← validity.boolAt "complete"))
  let guards ← validity.listAt "slices"
  let table ← raw.listAt "instructions"
  require (table.length > 0 && table.length ≤ 512)
  checkCopyCoverage raw validity table
  pure ⟨parameters, parameterTypes, returnType, mapping, guards, table, ← raw.listAt "body"⟩

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
