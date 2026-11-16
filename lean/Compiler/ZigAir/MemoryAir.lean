/-
// Copyright (C) 2026 OKcontract Pte. Ltd.
// SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryByteAccess
import Compiler.ZigAir.MemoryByteCopy

/-! Memory primitives plug into the same structured interpreter as scalar AIR.
Bulk-copy faults retain their completed prefix. Stack cleanup occurs at the invocation
boundary and does not rewind lifetime identities. Source guards are explicit
primitives, positioned by the decoder; they are never inferred from heap extent.
The current client admits 64-bit target layouts only. -/
namespace Compiler.ZigAir.MemoryAir
open Memory

inductive Ref where
  | local (id : Nat)
  | constant (value : Value)
  deriving DecidableEq, Repr

abbrev Env := Control.Env Value

def Ref.eval (ref : Ref) (env : Env) : Except Fault Value := do
  let value ← match ref with
    | .constant value => .ok value
    | .local id => match env id with | some value => .ok value | none => .error .malformed
  if value.valid then .ok value else .error .malformed

def Ref.natural (ref : Ref) (env : Env) : Except Fault Nat := do
  let .scalar (.int false 64 number) ← ref.eval env | .error .malformed
  .ok number.toNat

inductive Bound where
  | array (length : Nat)
  | slice (original : Ref)
  | unbounded
  deriving DecidableEq, Repr

def Bound.eval (bound : Bound) (env : Env) : Except Fault (Option Nat) := do
  match bound with
  | .unbounded => .ok none
  | .array length => .ok (some length)
  | .slice original =>
    let .slice _ _ length ← original.eval env | .error .malformed
    .ok (some length)

inductive Prim where
  | argument (index : Nat)
  | scalar (operation : Scalar.Prim)
  | alloc (child : Ty)
  | load (pointer : Ref)
  | store (pointer value : Ref)
  | copyBytes (target source : Ref)
  | pointerField (length : Bool) (pointer : Ref)
  | fieldPointer (pointer : Ref) (offset : Nat)
  | booleanNot (value : Ref)
  | unreachable
  | pointerCast (target : Ty) (pointer : Ref)
  | sliceCast (target : Ty) (slice : Ref)
  | arrayToSlice (pointer : Ref)
  | offsetPointer (subtract : Bool) (pointer count : Ref)
  | elementPointer (pointer index : Ref)
  | wordByteCast (writable many : Bool) (alignment : Nat) (pointer : Ref)
  | wordByteLoad (order : WordBytes.Order) (pointer : Ref)
  | wordByteStore (order : WordBytes.Order) (pointer value : Ref)
  | sliceElementPointer (slice index : Ref)
  | slice (target : Ty) (pointer length : Ref)
  | sliceLen (slice : Ref)
  | slicePtr (slice : Ref)
  | checkBounds (start finish : Ref) (upper : Bound)
  deriving DecidableEq, Repr

def scalarEnv (env : Env) : Scalar.Env := fun id =>
  match env id with | some (.scalar value) => some value | _ => none

def booleanNot : Value → Except Fault Value
  | .scalar (.bool flag) => .ok (.scalar (.bool (!flag)))
  | _ => .error .malformed

/-- Slice constness conversion preserves its logical extent and address. It
does not grant permission or access the referenced storage. -/
def sliceCast (target : Ty) (source : Value) : Except Fault Value := do
  let .slice (.slice writable child) address length := source | .error .malformed
  let .slice targetWritable targetChild := target | .error .malformed
  if (targetWritable && !writable) || targetChild != child then .error .unsupported
  else .ok (.slice target address length)

/-- Single-step primitives commit only on success. Bulk copying is interpreted
by `eval`, since a failed copy can have completed earlier byte stores. -/
def Prim.transition (prim : Prim) (args : List Value) (env : Env) (state : State) :
    Except Fault (Value × State) := do
  match prim with
  | .alloc child => allocate state child
  | .store pointer value =>
    let after ← Memory.store state (← pointer.eval env) (← value.eval env)
    .ok (.scalar .unit, after)
  | .wordByteStore order pointer value =>
    let after ← Memory.ByteAccess.write order state (← pointer.eval env) (← value.eval env)
    .ok (.scalar .unit, after)
  | other =>
    let value ← match other with
      | .argument index => match args[index]? with | some value => .ok value | none => .error .malformed
      | .scalar operation => match operation.eval [] (scalarEnv env) with
        | .ok value => .ok (.scalar value)
        | .error fault => .error (.scalar fault)
      | .load pointer => do Memory.load state (← pointer.eval env)
      | .pointerField length pointer => do Memory.pointerField length (← pointer.eval env)
      | .fieldPointer pointer offset => do Memory.fieldPointer state (← pointer.eval env) offset
      | .booleanNot reference => do MemoryAir.booleanNot (← reference.eval env)
      | .unreachable => .error (.scalar .illegalBehavior)
      | .pointerCast target pointer => do Memory.pointerCast state target (← pointer.eval env)
      | .sliceCast target reference => do MemoryAir.sliceCast target (← reference.eval env)
      | .arrayToSlice reference => do ScalarBytes.arrayToSlice (← reference.eval env)
      | .offsetPointer subtract pointer count => do Memory.offsetPointer state subtract (← pointer.eval env) (← count.natural env)
      | .elementPointer pointer index => do Memory.elementPointer state (← pointer.eval env) (← index.natural env)
      | .wordByteCast writable many alignment pointer => do
        Memory.ByteAccess.cast state writable many alignment (← pointer.eval env)
      | .wordByteLoad order pointer => do Memory.ByteAccess.read order state (← pointer.eval env)
      | .sliceElementPointer view index => do Memory.sliceElementPointer state (← view.eval env) (← index.natural env)
      | .slice target pointer length => do makeSlice state target (← pointer.eval env) (← length.natural env)
      | .sliceLen view => do
        let .slice _ _ length ← view.eval env | .error .malformed
        .ok (.scalar (.int false 64 length))
      | .slicePtr view => do
        let .slice (.slice writable child) pointer _ ← view.eval env | .error .malformed
        .ok (.pointer (.pointer writable true child) pointer)
      | .checkBounds start finish upper => do
        checkSliceBounds (← start.natural env) (← finish.natural env) (← upper.eval env)
        .ok (.scalar .unit)
      | .alloc _ | .store .. | .wordByteStore .. | .copyBytes .. => .error .malformed
    .ok (value, state)

def Prim.eval (prim : Prim) (args : List Value) (env : Env) (state : State) : Except Fault Value × State :=
  match prim with
  | .copyBytes target source =>
    match target.eval env, source.eval env with
    | .ok target, .ok source =>
      let (result, after) := ByteRange.copy state target source
      (result.map (fun _ => .scalar .unit), after)
    | .error fault, _ | _, .error fault => (.error fault, state)
  | _ =>
    match prim.transition args env state with
    | .ok (value, after) => (.ok value, after)
    | .error fault => (.error fault, state)

def semantics : Control.Semantics Ty Prim Ref Value Fault State where
  hasType := Value.hasType
  truth := fun value => match value with | .scalar (.bool flag) => some flag | _ => none
  evalRef := Ref.eval
  evalPrim := Prim.eval
  malformed := .malformed

abbrev Code := Control.Code Ty Prim Ref

structure Program (loops : Bool := false) where
  parameters : List Ty
  returnType : Ty
  body : Control.Code Ty Prim Ref loops
  deriving DecidableEq, Repr

def Program.accepts (program : Program loops) (args : List Value) (state : State) : Bool :=
  state.valid && args.length = program.parameters.length &&
    (args.zip program.parameters).all (fun (value, ty) => value.hasType ty)

/-- Common terminal boundary for finite and resumable executions. -/
def Program.finish (returnType : Ty) (mark : Nat) : Control.Outcome Value Fault State → Except Fault Value × State
  | .returned value after =>
    (if value.hasType returnType then .ok value else .error .malformed, cleanup mark after)
  | .fault reason after => (.error reason, cleanup mark after)
  | .jumped _ _ _ after => (.error .malformed, cleanup mark after)

def Program.run (program : Program) (args : List Value) (state : State) : Except Fault Value × State :=
  if program.accepts args state then
    Program.finish program.returnType state.nextId (program.body.eval semantics args (fun _ => none) state)
  else (.error .malformed, state)

end Compiler.ZigAir.MemoryAir
