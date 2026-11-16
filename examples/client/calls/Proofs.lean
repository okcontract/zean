/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import CellCalls.Generated
import Compiler.ZigAir.Verify.Machine
import Compiler.ZigAir.Verify.Words

namespace CellCalls
open Compiler.ZigAir Compiler.ZigAir.Memory MemoryCallMachine Std.WP Lean.Order
open MemoryAir.Verify WordArray
set_option maxRecDepth 4096
set_option maxHeartbeats 1000000

theorem put_checked (state : State) (view : View) (value : BitVec 32)
    (valid : state.valid = true) (writable : Writable state view) (nonempty : 0 < view.length) :
    Triple (invoke Generated.functions Generated.FunctionId.fn_put [view.pointer 0, number value])
      (fun before => before = state)
      (fun result after => result = .scalar .unit ∧ after.valid = true) ResourceOnly := by
  have initialFrame := StackFrame.refl state valid
  dsimp only [Generated.functions, Generated.FunctionId.fn_put, Generated.fn_put, ResourceOnly]
  machine_vcgen
  all_goals try simp only [Function.accepts, ResourcePolicy.cleanup, MemoryCallMachine.Observes, unwind] at *
  air_normalize
  air_reduce
  air_reduce
  air_word_finish

def putContract : MemoryCallMachine.Contract Generated.functions Generated.FunctionId.fn_put where
  precondition := fun args state => ∃ view value,
    args = [view.pointer 0, number value] ∧ state.valid = true ∧ Writable state view ∧ 0 < view.length
  postcondition := fun _ _ result after => result = .scalar .unit ∧ after.valid = true
  exceptions := fun _ _ => ResourceOnly
  checked := by
    intro args before pre fuel
    obtain ⟨view, value, rfl, valid, writable, nonempty⟩ := pre
    exact sound _ _ _ _ (put_checked before view value valid writable nonempty) before rfl fuel

theorem put_spec (args : List Value) (post : MemoryCallMachine.Postcondition) (errors : Exceptions) :
    Triple (invoke Generated.functions Generated.FunctionId.fn_put args)
      (fun state => ⌜putContract.precondition args state⌝ ⊓
        ((⨅ value, ⨅ after, ⌜putContract.postcondition args state value after⌝ ⇨ post value after) ⊓
        (⨅ fault, ⨅ after, ⌜putContract.exceptions args state fault after⌝ ⇨ errors fault after))) post errors :=
  putContract.apply args post errors

attribute [local irreducible] Generated.fn_put

/-- The caller uses the helper's checked summary, with its body opaque. -/
theorem update_checked (state : State) (view : View) (value : BitVec 32)
    (valid : state.valid = true) (writable : Writable state view) (nonempty : 0 < view.length) :
    Triple (invoke Generated.functions Generated.FunctionId.fn_update [view.pointer 0, number value])
      (fun before => before = state)
      (fun result after => result = .scalar .unit ∧ after.valid = true) ResourceOnly := by
  have initialFrame := StackFrame.refl state valid
  have ready : putContract.precondition [view.pointer 0, number value] state :=
    ⟨view, value, rfl, valid, writable, nonempty⟩
  have helper := put_spec
  dsimp only [Generated.functions, Generated.fn_update, Generated.FunctionId.fn_update,
    Generated.FunctionId.fn_put, ResourceOnly] at helper ⊢
  machine_vcgen [helper]
  all_goals clear helper
  all_goals try simp only [putContract, Function.accepts, ResourcePolicy.cleanup,
    MemoryCallMachine.Observes, unwind, ResourceOnly] at *
  air_normalize
  air_reduce
  air_reduce
  air_word_finish

/-- All finite prefixes avoid modeled memory faults. Out-of-memory outcomes
remain permitted; this is neither termination nor native resource adequacy. -/
theorem safe (state : State) (view : View) (value : BitVec 32)
    (valid : state.valid = true) (writable : Writable state view) (nonempty : 0 < view.length) :
    Safe Generated.functions
      (start Generated.functions Generated.FunctionId.fn_update [view.pointer 0, number value] state) :=
  safe_of_spec _ _ _ _ (update_checked state view value valid writable nonempty) state rfl
    (fun _ _ allowed => allowed)

end CellCalls
