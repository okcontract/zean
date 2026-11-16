/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryAirLaws

/-! Slice evaluation equations, independent of contracts and proof automation. -/
namespace Compiler.ZigAir.MemoryAir
open Memory

def sliceLength (value : Value) : Except Fault Value :=
  match value with
  | .slice _ _ length => .ok (.scalar (.int false 64 length))
  | _ => .error .malformed

@[simp] theorem sliceLength_value (ty : Ty) (address : Address) (length : Nat) :
    sliceLength (.slice ty address length) = .ok (.scalar (.int false 64 length)) := rfl

theorem Prim.eval_slice_length (view : Ref) (args : List Value) (env : Env) (state : State) :
    (Prim.sliceLen view).eval args env state = (view.eval env >>= sliceLength, state) := by
  cases read : view.eval env with
  | error => simp [Prim.eval, Prim.transition, read, bind, Except.bind]
  | ok value => cases value <;> simp [Prim.eval, Prim.transition, read, sliceLength, bind, Except.bind]

def slicePointer : Value → Except Fault Value
  | .slice (.slice writable child) address _ => .ok (.pointer (.pointer writable true child) address)
  | _ => .error .malformed

theorem Prim.eval_slice_pointer (view : Ref) (args : List Value) (env : Env) (state : State) :
    (Prim.slicePtr view).eval args env state = (view.eval env >>= slicePointer, state) := by
  cases read : view.eval env with
  | error => simp [Prim.eval, Prim.transition, read, bind, Except.bind]
  | ok value =>
    cases value <;> simp [Prim.eval, Prim.transition, read, slicePointer, bind, Except.bind]
    next type address length => cases type <;> rfl

theorem Prim.eval_pointer_field (length : Bool) (pointer : Ref) (args : List Value) (env : Env) (state : State) :
    (Prim.pointerField length pointer).eval args env state =
      (pointer.eval env >>= Memory.pointerField length, state) := by
  cases read : pointer.eval env with
  | error => simp [Prim.eval, Prim.transition, read, bind, Except.bind]
  | ok value =>
    cases projected : Memory.pointerField length value <;>
      simp [Prim.eval, Prim.transition, read, projected, bind, Except.bind]

end Compiler.ZigAir.MemoryAir
