/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryCallVerification
import Compiler.ZigAir.MemoryAutomation

/-! Synthetic call clients and negative execution controls. These are not
native captures. The caller proof uses a callee theorem, not its implementation. -/
namespace Compiler.ZigAir.MemoryCall.Controls
open Memory MemoryAir.Verify Control.Verification Std.WP Lean.Order
set_option maxRecDepth 4096

def helper : MemoryAir.Program :=
  ⟨[.scalar .bool], .scalar .bool,
    .bind 3 (.scalar .bool) (.argument 0) (.ret (.local 3))⟩

def helperTarget : Target := Target.ofMemory helper

theorem helper_checked (value : Value) (state : State) (valid : state.valid = true)
    (typed : value.hasType (.scalar .bool) = true) :
    Triple (helperTarget.invoke [value]) (fun before => before = state)
      (fun result after => result = value ∧ after = state) (fun _ _ => False) := by
  apply Target.memory_contract
  unfold helper
  air_vcgen
  air_finish

@[spec] theorem helper_spec (value : Value) (post : Postcondition) (errors : FaultCondition) :
    Triple (helperTarget.invoke [value])
      (fun state => ⌜state.valid = true⌝ ⊓ (⌜value.hasType (.scalar .bool) = true⌝ ⊓ post value state)) post errors := by
  constructor
  intro state h
  simp only [meet_prop_eq_and, ofProp_prop_eq] at h
  have checked := (helper_checked value state h.1 h.2.1).le_wp state rfl
  simp only [wp, WP.wpTrans] at checked ⊢
  cases executed : helperTarget.invoke [value] state with
  | error fault after => simp only [executed] at checked
  | ok result after =>
    simp only [executed] at checked ⊢
    obtain ⟨rfl, rfl⟩ := checked
    exact h.2.2

def caller : Program :=
  ⟨[.scalar .bool], .scalar .bool,
    .bind 9 (.scalar .bool) (.memory (.argument 0))
      (.bind 11 (.scalar .bool) (.call helperTarget [.local 9]) (.ret (.local 11)))⟩

theorem caller_body (flag : Bool) (state : State) (valid : state.valid = true) :
    BodyContract caller.enableLoops [.scalar (.bool flag)] (fun _ _ _ => False) state
      (fun result after => result = .scalar (.bool flag) ∧ after = state) (fun _ _ => False) := by
  dsimp only [BodyContract, caller, Program.enableLoops, Control.Code.enableLoops]
  set_option experimental.vcgen true in vcgen
  all_goals simp only [semantics] at *
  air_normalize
  air_reduce
  all_goals simp_all [finishPost, cleanup_initial]

theorem caller_checked (flag : Bool) :
    Triple (caller.target.invoke [.scalar (.bool flag)]) (fun state => state.valid = true)
      (fun result after => result = .scalar (.bool flag) ∧ after.valid = true) (fun _ _ => False) := by
  apply target_contract
  · intro state valid
    simp [caller, Program.accepts, valid, bool_typed]
  · intro state valid
    have checked := caller_body flag state valid
    constructor
    intro before same
    have h := checked.le_wp before same
    rw [wp_code] at h ⊢
    apply Control.Verification.pre_mono semantics [.scalar (.bool flag)] (fun _ _ _ => False)
      caller.enableLoops.body _ _ _ _ ?_ (fun _ _ h => h) _ _ h
    intro flow after h
    apply finishPost_mono _ _ _ _ _ _ ?_ (fun _ _ h => h) flow after h
    intro value after h
    exact ⟨h.1, h.2 ▸ valid⟩

/-- A malformed argument is checked by the actual callee invocation. -/
theorem bad_argument : helperTarget.execute [.scalar .unit] {} = (.error .malformed, {}) := rfl

def escapes : MemoryAir.Program :=
  ⟨[], .pointer true false usize,
    .bind 0 (.pointer true false usize) (.alloc usize) (.ret (.local 0))⟩

def useDangling : Program :=
  ⟨[], usize, .bind 0 (.pointer true false usize) (.call (Target.ofMemory escapes) [])
    (.bind 1 usize (.memory (.load (.local 0))) (.ret (.local 1)))⟩

/-- Type-valid returned pointers are not automatically live after cleanup. -/
theorem dangling_return_faults : (useDangling.run [] {}).1 = .error .unallocated := rfl

def callerState : State :=
  ⟨[(0, ⟨8, usize, [(0, .scalar (.int false 64 0))], true, false⟩)], 1, 16⟩

def writeThenFail : MemoryAir.Program :=
  ⟨[], .scalar .unit,
    .bind 0 (.scalar .unit)
      (.store (.constant (.pointer (.pointer true false usize) ⟨0, 0⟩))
        (.constant (.scalar (.int false 64 7))))
      (.bind 1 usize (.argument 0) (.ret (.constant (.scalar .unit))))⟩

def failedCall : Program :=
  ⟨[], .scalar .unit, .bind 0 (.scalar .unit) (.call (Target.ofMemory writeThenFail) [])
    (.ret (.constant (.scalar .unit)))⟩

theorem callee_failure : (failedCall.run [] callerState).1 = .error .malformed := rfl

/-- A callee fault and both invocation cleanups preserve a reached caller write. -/
theorem callee_failure_keeps_write :
    load (failedCall.run [] callerState).2 (.pointer (.pointer true false usize) ⟨0, 0⟩) =
      .ok (.scalar (.int false 64 7)) := rfl

end Compiler.ZigAir.MemoryCall.Controls
