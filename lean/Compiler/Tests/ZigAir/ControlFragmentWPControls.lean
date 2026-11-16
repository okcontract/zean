/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.ControlFragmentWP
import Compiler.ZigAir.MemoryAutomation

/-! Synthetic composition controls; these are not native capture evidence. -/
namespace Compiler.ZigAir.Control.Verification.FragmentControls
open Memory MemoryAir MemoryAir.Verify Std.WP
set_option maxRecDepth 4096

private def bindFlag : List (Instruction Ty Prim) := [⟨9, .scalar .bool, .argument 0⟩]

theorem helper (state : State) (env : MemoryAir.Env) (flag : Bool) :
    Triple (Fragment.mk (sem := semantics) (args := [.scalar (.bool flag)]) bindFlag env)
      (fun before => before = state)
      (fun locals after => locals = env.set 9 (.scalar (.bool flag)) ∧ after = state)
      (fun _ _ => False) := by
  unfold bindFlag
  air_vcgen

theorem composed (state : State) (env : MemoryAir.Env) (flag : Bool) :
    Triple (Task.code (prependCode bindFlag (.ret (.local 9))) env :
      Task semantics [.scalar (.bool flag)] (fun _ _ _ => False))
      (fun before => before = state)
      (fun flow after => flow = .returned (.scalar (.bool flag)) ∧ after = state) (fun _ _ => False) := by
  apply prefix_contract semantics [.scalar (.bool flag)] (fun _ _ _ => False) bindFlag _ env
    _ _ _ _ (helper state env flag)
  intro locals
  air_vcgen

/-- A write in the helper is retained if its continuation faults. -/
theorem reached_write (state written : State) (address : Address) (value : Value)
    (valueValid : value.valid = true)
    (stored : store state (.pointer (.pointer true false WordArray.word) address) value = .ok written) :
    Triple (Task.code (prependCode
      [⟨71, .scalar .unit, .store
        (.constant (.pointer (.pointer true false WordArray.word) address)) (.constant value)⟩]
      (.bind 13 (.scalar .unit) (.argument 0) (.ret (.constant (.scalar .unit))))) (fun _ => none) :
      Task semantics [] (fun _ _ _ => False))
      (fun before => before = state) (fun _ _ => False)
      (fun fault after => fault = .malformed ∧ after = written) := by
  air_vcgen

end Compiler.ZigAir.Control.Verification.FragmentControls
