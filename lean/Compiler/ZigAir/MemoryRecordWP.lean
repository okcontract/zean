/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryAutomation
import Compiler.ZigAir.MemoryRecordFields
import Compiler.ZigAir.MemoryStackFrame

namespace Compiler.ZigAir.MemoryAir
open Memory

theorem Prim.eval_field_pointer (pointer : Ref) (offset : Nat) (args : List Value) (env : Env) (state : State) :
    (Prim.fieldPointer pointer offset).eval args env state =
      (pointer.eval env >>= (fun value => Memory.fieldPointer state value offset), state) := by
  cases evaluated : pointer.eval env with
  | error fault => simp [Prim.eval, Prim.transition, evaluated, bind, Except.bind]
  | ok value =>
    cases selected : Memory.fieldPointer state value offset <;>
      simp [Prim.eval, Prim.transition, evaluated, selected, bind, Except.bind]

theorem Prim.eval_zero_field (pointer : Ref) (offset : Nat) (args : List Value) (env : Env) (state : State) :
    (Prim.checkZeroField pointer offset).eval args env state =
      (do
        Memory.checkZeroField state (← pointer.eval env) offset
        .ok (.scalar .unit), state) := by
  cases evaluated : pointer.eval env with
  | error fault => simp [Prim.eval, Prim.transition, evaluated, bind, Except.bind]
  | ok value =>
    cases checked : Memory.checkZeroField state value offset <;>
      simp [Prim.eval, Prim.transition, evaluated, checked, bind, Except.bind]

namespace Verify
open Std.WP Lean.Order Control.Verification

@[spec] theorem field_pointer_spec (pointer : Ref) (offset : Nat) (args : List Value) (env : Env)
    (post : Postcondition) (errors : FaultCondition) :
    Triple (Atomic.mk (sem := semantics) (args := args) (.fieldPointer pointer offset) env)
      (fun state =>
        (⨅ value, ⌜(pointer.eval env >>= (fun value => Memory.fieldPointer state value offset)) = .ok value⌝ ⇨ post value state) ⊓
        (⨅ fault, ⌜(pointer.eval env >>= (fun value => Memory.fieldPointer state value offset)) = .error fault⌝ ⇨ errors fault state)) post errors :=
  readonly_spec (.fieldPointer pointer offset) args env
    (fun state => pointer.eval env >>= (fun value => Memory.fieldPointer state value offset))
    (Prim.eval_field_pointer pointer offset args env) post errors

end Verify
end Compiler.ZigAir.MemoryAir

attribute [air_simps] Compiler.ZigAir.MemoryAir.booleanNot

namespace Compiler.ZigAir.Memory

/-- Fresh invocation locals preserve a field selection in the caller's live
object. The original checked selection supplies its allocation identity. -/
theorem StackFrame.field_pointer (frame : StackFrame before after)
    (selected : fieldPointer before (.pointer (.pointer writable many owner) address) offset = .ok pointer) :
    fieldPointer after (.pointer (.pointer writable many owner) address) offset = .ok pointer := by
  obtain ⟨layout, cell, _, accessed, _⟩ := fieldPointer_parent before writable many owner address offset pointer selected
  have found := (access_success_region before address layout false cell accessed).1
  exact (fieldPointer_eq_of_lookup before after writable many owner address offset
    ((frame.old_lookup _ _ found).trans found.symm)).trans selected

grind_pattern StackFrame.field_pointer => StackFrame before after,
  fieldPointer before (.pointer (.pointer writable many owner) address) offset,
  (Except.ok pointer : Except Fault Value)

end Compiler.ZigAir.Memory
