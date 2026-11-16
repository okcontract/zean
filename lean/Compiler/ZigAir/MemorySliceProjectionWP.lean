/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryPrimitiveWP
import Compiler.ZigAir.MemorySliceLaws

namespace Compiler.ZigAir.MemoryAir
open Memory

theorem Prim.eval_slice_cast (target : Ty) (reference : Ref) (args : List Value) (env : Env) (state : State) :
    (Prim.sliceCast target reference).eval args env state = (reference.eval env >>= MemoryAir.sliceCast target, state) := by
  cases evaluated : reference.eval env with
  | error fault => simp [Prim.eval, Prim.transition, evaluated, bind, Except.bind]
  | ok value =>
    cases casted : MemoryAir.sliceCast target value <;>
      simp [Prim.eval, Prim.transition, evaluated, casted, bind, Except.bind]

end Compiler.ZigAir.MemoryAir

namespace Compiler.ZigAir.MemoryAir.Verify
open Memory Std.WP Lean.Order Control.Verification

@[spec] theorem array_to_slice_spec (reference : Ref) (args : List Value) (env : Env)
    (post : Postcondition) (errors : FaultCondition) :
    Triple (Atomic.mk (sem := semantics) (args := args) (.arrayToSlice reference) env)
      (fun state =>
        (⨅ value, ⌜(reference.eval env >>= ScalarBytes.arrayToSlice) = .ok value⌝ ⇨ post value state) ⊓
        (⨅ fault, ⌜(reference.eval env >>= ScalarBytes.arrayToSlice) = .error fault⌝ ⇨ errors fault state)) post errors := by
  apply readonly_spec (.arrayToSlice reference) args env
    (fun _ => reference.eval env >>= ScalarBytes.arrayToSlice)
  intro state
  cases evaluated : reference.eval env with
  | error fault => simp [Prim.eval, Prim.transition, evaluated, bind, Except.bind]
  | ok value =>
    cases converted : ScalarBytes.arrayToSlice value <;>
      simp [Prim.eval, Prim.transition, evaluated, converted, bind, Except.bind]

@[spec] theorem slice_cast_spec (target : Ty) (reference : Ref) (args : List Value) (env : Env)
    (post : Postcondition) (errors : FaultCondition) :
    Triple (Atomic.mk (sem := semantics) (args := args) (.sliceCast target reference) env)
      (fun state =>
        (⨅ value, ⌜(reference.eval env >>= sliceCast target) = .ok value⌝ ⇨ post value state) ⊓
        (⨅ fault, ⌜(reference.eval env >>= sliceCast target) = .error fault⌝ ⇨ errors fault state)) post errors :=
  readonly_spec (.sliceCast target reference) args env (fun _ => reference.eval env >>= sliceCast target)
    (Prim.eval_slice_cast target reference args env) post errors

@[spec] theorem slice_length_spec (view : Ref) (args : List Value) (env : Env)
    (post : Postcondition) (errors : FaultCondition) :
    Triple (Atomic.mk (sem := semantics) (args := args) (.sliceLen view) env)
      (fun state =>
        (⨅ value, ⌜(view.eval env >>= sliceLength) = .ok value⌝ ⇨ post value state) ⊓
        (⨅ fault, ⌜(view.eval env >>= sliceLength) = .error fault⌝ ⇨ errors fault state)) post errors :=
  readonly_spec (.sliceLen view) args env (fun _ => view.eval env >>= sliceLength)
    (Prim.eval_slice_length view args env) post errors

@[spec] theorem slice_pointer_spec (view : Ref) (args : List Value) (env : Env)
    (post : Postcondition) (errors : FaultCondition) :
    Triple (Atomic.mk (sem := semantics) (args := args) (.slicePtr view) env)
      (fun state =>
        (⨅ value, ⌜(view.eval env >>= slicePointer) = .ok value⌝ ⇨ post value state) ⊓
        (⨅ fault, ⌜(view.eval env >>= slicePointer) = .error fault⌝ ⇨ errors fault state)) post errors :=
  readonly_spec (.slicePtr view) args env (fun _ => view.eval env >>= slicePointer)
    (Prim.eval_slice_pointer view args env) post errors

@[spec] theorem pointer_field_spec (length : Bool) (pointer : Ref) (args : List Value) (env : Env)
    (post : Postcondition) (errors : FaultCondition) :
    Triple (Atomic.mk (sem := semantics) (args := args) (.pointerField length pointer) env)
      (fun state =>
        (⨅ value, ⌜(pointer.eval env >>= Memory.pointerField length) = .ok value⌝ ⇨ post value state) ⊓
        (⨅ fault, ⌜(pointer.eval env >>= Memory.pointerField length) = .error fault⌝ ⇨ errors fault state)) post errors :=
  readonly_spec (.pointerField length pointer) args env (fun _ => pointer.eval env >>= Memory.pointerField length)
    (Prim.eval_pointer_field length pointer args env) post errors

end Compiler.ZigAir.MemoryAir.Verify
