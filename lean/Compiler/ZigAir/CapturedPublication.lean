/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.AtomicPublication
import Compiler.ZigAir.Captured

namespace Compiler.ZigAir.CapturedPublication
open Captured (Raw)
open AtomicPublication

/-! Decode the AIR for `publish` and `readEntry`. The order of the writer's
stores matters, as do their operands. On the reader side, the load from the
slot belongs on the branch where the flag equals one. The decoder checks
both instruction tables and their bodies, down to the value each branch
returns. If Zig changes how it compiles either function, revisit these checks. -/

private abbrev Fields := List (String × Raw)
private def num (n : Nat) : Raw := .number n
private def ids (ns : List Nat) : Raw := .array (ns.map num)
private def kind (s : String) : Raw := .object [("kind", .string s)]
private def byte : Raw := .object [("kind", .string "int"), ("bits", num 8),
  ("signedness", .string "unsigned")]
private def byteTy := Memory.Ty.scalar (.int false 8)
private def reg (id : Nat) : Raw := .object [("kind", .string "instruction"), ("index", num id)]
private def literal (n : Nat) : Raw := .object [("kind", .string "constant"),
  ("type", byte), ("value", num n)]

/-- JSON objects are unordered. Comparison rejects missing and extra fields
and fails closed beyond the depth of the admitted pointer and instruction data. -/
private def equal : Nat → Raw → Raw → Bool
  | 0, _, _ => false
  | _ + 1, .null, .null => true
  | _ + 1, .number a, .number b => a == b
  | _ + 1, .string a, .string b => a == b
  | _ + 1, .boolean a, .boolean b => a == b
  | n + 1, .array a, .array b =>
    a.length == b.length && (a.zip b).all fun (x, y) => equal n x y
  | n + 1, .object a, .object b =>
    a.length == b.length && a.all fun (key, x) =>
      ((Raw.object b).get key).any (equal n x)
  | _ + 1, _, _ => false

private def inst (id : Nat) (tag : String) (ty : Raw) (fields : Fields) : Raw :=
  .object ([("index", num id), ("tag", .string tag), ("type", ty),
    ("payloadVisited", .boolean true)] ++ fields)

private def arg (id : Nat) (ty : Raw) := inst id "arg" ty [("zirParameterIndex", num id)]
private def ret (id : Nat) (value : Raw) := inst id "ret" (kind "noreturn") [("operand", value)]
private def slotIndex : Slot → Nat | .first => 0 | .second => 1

private def writeInst (id : Nat) : Write → Raw
  | .entry dst src => inst id "store" (kind "void")
    [("lhs", reg (slotIndex dst)), ("rhs", reg (3 + slotIndex src))]
  | .ready order =>
    let name := match order with | .release => "release" | .monotonic => "monotonic"
    inst id ("atomic_store_" ++ name) (kind "void")
      [("ordering", .string name), ("lhs", reg 2), ("rhs", literal 1)]

private def decodeWrite (id : Nat) (raw : Raw) : Option Write :=
  let entries := [Slot.first, .second].flatMap fun dst =>
    [Slot.first, .second].map fun src => Write.entry dst src
  (entries ++ [Write.ready .release]).find? fun op => equal 16 (writeInst id op) raw

private def readerTable (args : List Raw) (order : LoadOrder) : List Raw :=
  let name := match order with | .acquire => "acquire" | .monotonic => "monotonic"
  args.mapIdx arg ++ [
    inst 2 "block" (kind "void") [("body", ids [3, 4, 8])],
    inst 3 "atomic_load" byte [("operand", reg 1), ("ordering", .string name)],
    inst 4 "cmp_eq" (kind "bool") [("lhs", reg 3), ("rhs", literal 1)],
    inst 5 "load" byte [("operand", reg 0)], ret 6 (reg 5),
    inst 7 "br" (kind "noreturn") [("target", num 2), ("operand", kind "unit")],
    inst 8 "cond_br" (kind "noreturn")
      [("condition", reg 4), ("thenBody", ids [5, 6]), ("elseBody", ids [7])],
    ret 9 (literal 0)]

private def parameters (raw : Raw) (types : List Memory.Ty) (result : Memory.Ty) :
    Option (List Raw) := do
  let input ← Captured.prepare raw
  let signature ← raw.get "signature"
  let convention := Raw.object [("aarch64_aapcs_darwin",
    .object [("incoming_stack_alignment", .null)])]
  Captured.require (!(← signature.boolAt "genericInstance") &&
    equal 4 convention (← signature.get "callingConvention") &&
    (raw.get "specialization").isNone && input.guards.isEmpty &&
    input.parameters == types && input.returnType == result)
  signature.listAt "parameters"

def decode (writer reader : Raw) : Option Protocol := do
  Captured.require (equal 128 (← writer.get "configuration") (← reader.get "configuration"))
  let ptr (writable : Bool) := Memory.Ty.pointer writable false byteTy
  let wargs ← parameters writer [ptr true, ptr true, ptr true, byteTy, byteTy] (.scalar .unit)
  let rargs ← parameters reader [ptr false, ptr false] byteTy
  let table ← writer.listAt "instructions"
  Captured.require (table.length == 9 && equal 16 (ids (List.range 9)) (← writer.get "body") &&
    equal 16 (.array (wargs.mapIdx arg)) (.array (table.take 5)) &&
    equal 16 (ret 8 (kind "unit")) (← table[8]?))
  let writes ← ((table.drop 5).take 3).zipIdx.mapM fun (raw, offset) =>
    decodeWrite (5 + offset) raw
  let loads ← reader.listAt "instructions"
  let order ← match ← (← loads[3]?).textAt "ordering" with
    | "acquire" => some LoadOrder.acquire
    | _ => none
  Captured.require (equal 16 (ids [0, 1, 2, 9]) (← reader.get "body") &&
    equal 16 (.array (readerTable rargs order)) (.array loads))
  pure ⟨writes, order⟩

end Compiler.ZigAir.CapturedPublication
