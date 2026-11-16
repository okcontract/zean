/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.Tutorial.Calls.Generated
import Compiler.ZigAir.Verify.Machine
import Compiler.ZigAir.MemoryCallMachineTermination
import Compiler.ZigAir.Verify.Words
import Compiler.Tutorial.Buffer.Contracts
import Compiler.ZigAir.MemoryCleanupContracts

namespace Compiler.Tutorial.Calls
open Compiler.ZigAir Compiler.ZigAir.Memory MemoryAir.Verify MemoryCallMachine
open Memory.WordArray Control.Verification Std.WP Lean.Order
set_option maxRecDepth 4096
set_option maxHeartbeats 2000000

def size (n : Nat) : Value := .scalar (.int false 64 n)

def InsideInputs (args : List Value) (state : State) : Prop :=
  state.valid = true ∧ ∃ left right : Nat,
    args = [size left, size right] ∧ left < addressLimit ∧ right < addressLimit

def comparison : List Value → Value
  | [.scalar (.int _ _ left), .scalar (.int _ _ right)] => .scalar (.bool (decide (left < right)))
  | _ => .scalar .unit

theorem inside_exact (left right : Nat) (state : State) (valid : state.valid = true)
    (leftBound : left < addressLimit) (rightBound : right < addressLimit) :
    Triple (invoke Generated.functions Generated.FunctionId.fn_inside [size left, size right]) (fun before => before = state)
      (fun result after => result = .scalar (.bool (decide (left < right))) ∧ after = state)
      (fun _ _ => False) := by
  have leftTyped := usize_typed left leftBound
  have rightTyped := usize_typed right rightBound
  have leftValid := unsigned_valid 64 left leftBound
  have rightValid := unsigned_valid 64 right rightBound
  change Triple (verify Generated.functions Generated.FunctionId.fn_inside [size left, size right]
    (fun _ _ _ => False)) _ _ _
  rw [verify_at _ _ Generated.fn_inside rfl]
  dsimp only [Generated.fn_inside, size]
  machine_vcgen
  machine_normalize
  air_reduce
  all_goals simp_all [cleanup_initial]
  all_goals grind [Value.hasType, Value.type, Value.valid, Scalar.Value.type, Scalar.Value.valid]


def insideContract : MemoryCallMachine.Contract Generated.functions Generated.FunctionId.fn_inside where
  precondition := InsideInputs
  postcondition := fun args before value after => value = comparison args ∧ after = before
  exceptions := fun _ _ _ _ => False
  checked := by
    intro args state h fuel
    obtain ⟨valid, left, right, rfl, leftBound, rightBound⟩ := h
    have observed := sound _ _ _ _ (inside_exact left right state valid leftBound rightBound) state rfl fuel
    exact MemoryCallMachine.Observes.mono _ _ _ _
      (fun _ _ h => by simpa [comparison, size, Int.ofNat_lt] using h)
      (fun _ _ h => h) _ observed

@[spec] theorem inside_spec (args : List Value) (post : MemoryCallMachine.Postcondition) (errors : FaultCondition) :
    Triple (invoke Generated.functions Generated.FunctionId.fn_inside args)
      (fun state => ⌜insideContract.precondition args state⌝ ⊓
        ((⨅ value, ⨅ after, ⌜insideContract.postcondition args state value after⌝ ⇨ post value after) ⊓
         (⨅ fault, ⨅ after, ⌜insideContract.exceptions args state fault after⌝ ⇨ errors fault after))) post errors :=
  insideContract.apply args post errors

def arguments (view : View) (index : Nat) (value : BitVec 32) : List Value :=
  [view.buffer, size view.length, size index, number value]

theorem replace_checked (state : State) (view : View) (index : Nat) (value : BitVec 32)
    (valid : state.valid = true) (writable : Writable state view) (indexBound : index < addressLimit) :
    Triple (invoke Generated.functions Generated.FunctionId.fn_replace (arguments view index value))
      (fun before => before = state)
      (fun result after => Buffer.Spec.SafeResult state view index value (.ok result) after)
      (fun fault after => Buffer.Spec.SafeResult state view index value (.error fault) after) := by
  have frame := StackFrame.refl state valid
  have lengthBound := view_width state view valid writable
  have indexTyped := usize_typed index indexBound
  have lengthTyped := usize_typed view.length lengthBound
  change Triple (verify Generated.functions Generated.FunctionId.fn_replace (arguments view index value)
    (fun _ _ _ => False)) _ _ _
  rw [verify_at _ _ Generated.fn_replace rfl]
  dsimp only [Generated.fn_replace, arguments, size]
  machine_vcgen [inside_spec]
  machine_normalize [insideContract, InsideInputs, comparison, size, Int.ofNat_lt]
  air_reduce
  all_goals try solve | exact ⟨by assumption, index, view.length, rfl, indexBound, lengthBound⟩
  all_goals try simp only [VC.finishPost] at *
  air_word_finish [Buffer.Spec.exhausted, Buffer.Spec.rejected, Buffer.Spec.replaced]


theorem safeResult_cleanup (before after : State) (view : View) (index : Nat) (value : BitVec 32)
    (result : Except Fault Value) (valid : before.valid = true)
    (safe : Buffer.Spec.SafeResult before view index value result after) :
    cleanup before.nextId after = after := by
  cases safe.effect with
  | exhausted _ heap | rejected _ _ heap => exact cleanup_heap_eq_initial before after valid heap
  | replaced _ direct _ stored heap =>
    have counters := store_keeps_counters before _ _ direct stored
    rw [← counters.1]
    exact cleanup_heap_eq_initial direct after (store_preserves_valid before _ _ direct valid stored) heap

def replaceContract (view : View) (index : Nat) (value : BitVec 32) :
    MemoryCallMachine.Contract Generated.functions Generated.FunctionId.fn_replace where
  precondition := fun args state => args = arguments view index value ∧ state.valid = true ∧
    Writable state view ∧ index < addressLimit
  postcondition := fun _ before result after => Buffer.Spec.SafeResult before view index value (.ok result) after
  exceptions := fun _ before fault after => Buffer.Spec.SafeResult before view index value (.error fault) after
  checked := by
    intro args state h fuel
    obtain ⟨rfl, valid, writable, bound⟩ := h
    exact sound _ _ _ _ (replace_checked state view index value valid writable bound) state rfl fuel

theorem replace_spec (view : View) (index : Nat) (value : BitVec 32)
    (args : List Value) (post : MemoryCallMachine.Postcondition) (errors : FaultCondition) :
    Triple (invoke Generated.functions Generated.FunctionId.fn_replace args)
      (fun state => ⌜(replaceContract view index value).precondition args state⌝ ⊓
        ((⨅ result, ⨅ after, ⌜(replaceContract view index value).postcondition args state result after⌝ ⇨ post result after) ⊓
         (⨅ fault, ⨅ after, ⌜(replaceContract view index value).exceptions args state fault after⌝ ⇨ errors fault after))) post errors :=
  (replaceContract view index value).apply args post errors

theorem safeResult_bool (before after : State) (view : View) (index : Nat) (value : BitVec 32)
    (result : Value) (safe : Buffer.Spec.SafeResult before view index value (.ok result) after) :
    result.hasType (.scalar .bool) = true := by
  cases safe.effect <;> rfl

theorem update_checked (state : State) (view : View) (index : Nat) (value : BitVec 32)
    (valid : state.valid = true) (writable : Writable state view) (indexBound : index < addressLimit) :
    Triple (invoke Generated.functions Generated.FunctionId.fn_update (arguments view index value))
      (fun before => before = state)
      (fun result after => Buffer.Spec.SafeResult state view index value (.ok result) after)
      (fun fault after => Buffer.Spec.SafeResult state view index value (.error fault) after) := by
  have lengthBound := view_width state view valid writable
  have indexTyped := usize_typed index indexBound
  have lengthTyped := usize_typed view.length lengthBound
  change Triple (verify Generated.functions Generated.FunctionId.fn_update (arguments view index value)
    (fun _ _ _ => False)) _ _ _
  rw [verify_at _ _ Generated.fn_update rfl]
  dsimp only [Generated.fn_update, arguments, size]
  machine_vcgen [replace_spec view index value]
  machine_normalize [replaceContract, arguments, size, VC.finishPost]
  air_reduce
  air_word_finish [safeResult_cleanup, safeResult_bool]

private def bounds (index : Nat) := (Finite.infer Generated.functions)[index]?.join
private theorem finite : Finite.Valid Generated.functions bounds := by decide +kernel

/-- Every invocation of this finite closure finishes, with its result or fault.
This certificate measures modeled transitions, not native stack capacity. -/
theorem update_terminates (args : List Value) (state : State) :
    Terminates Generated.functions
      (start Generated.functions Generated.FunctionId.fn_update args state) :=
  Finite.terminates finite _ rfl args state

end Compiler.Tutorial.Calls
