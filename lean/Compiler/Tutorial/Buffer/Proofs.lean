/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.Tutorial.Buffer.Spec
import Compiler.Tutorial.Buffer.Verification

/-! Universal memory-safety and functional proofs for both native captures.
No successful allocation, pointer access, store, or invocation is a premise. -/
namespace Compiler.Tutorial.Buffer
open Compiler.ZigAir Compiler.ZigAir.Memory Compiler.ZigAir.MemoryAir
open Compiler.ZigAir.Memory.WordArray

/-- Every valid caller state and writable view executes safely. The index is
any usize, including values outside the view. Old contents need not be initialized:
replacement never reads them. Source and native refinement remain separate. -/
theorem replace_safe (version : Version) (state : State) (view : View) (index : Nat) (value : BitVec 32)
    (initial : state.valid = true) (cap : Writable state view) (indexBound : index < addressLimit) :
    ∃ result after, (program version).run (arguments view index value) state = (result, after) ∧
      Spec.SafeResult state view index value result after := by
  have checked := MemoryAir.Verify.finite_sound (program version) (arguments view index value)
    (fun before => before = state) _ _ (replace_contract version state view index value initial cap indexBound)
    state rfl
  generalize ran : (program version).run (arguments view index value) state = execution at checked
  obtain ⟨result, after⟩ := execution
  refine ⟨result, after, rfl, ?_⟩
  cases result <;> exact checked

theorem fault_is_exhaustion (version : Version) (state : State) (view : View) (index : Nat) (value : BitVec 32)
    (initial : state.valid = true) (cap : Writable state view) (indexBound : index < addressLimit)
    (fault : Fault) (after : State)
    (observed : (program version).run (arguments view index value) state = (.error fault, after)) :
    fault = .outOfMemory := by
  obtain ⟨result, final, ran, safe⟩ := replace_safe version state view index value initial cap indexBound
  obtain ⟨rfl, rfl⟩ := Prod.mk.inj (ran.symm.trans observed)
  cases safe.effect
  rfl

/-- A successful call returns the exact bounds decision and realizes the
independent list specification, preserving every other initialized word. -/
theorem replacement_correct (version : Version) (state : State) (view : View) (items : List (BitVec 32))
    (index : Nat) (value : BitVec 32) (initial : state.valid = true) (cap : Writable state view)
    (represented : Represents state view items) (indexBound : index < addressLimit)
    (flag : Bool) (after : State)
    (observed : (program version).run (arguments view index value) state = (.ok (.scalar (.bool flag)), after)) :
    flag = decide (index < view.length) ∧ Represents after view (Spec.contents items index value) := by
  obtain ⟨result, final, ran, safe⟩ := replace_safe version state view index value initial cap indexBound
  obtain ⟨rfl, rfl⟩ := Prod.mk.inj (ran.symm.trans observed)
  cases safe.effect with
  | rejected after outside heap =>
    refine ⟨by simp [Nat.not_lt_of_ge outside], ?_⟩
    have outsideItems : items.length ≤ index := by rw [represented.1]; exact outside
    simpa [Spec.contents, List.set_eq_of_length_le outsideItems] using
      represents_heap_eq state _ view items heap represented
  | replaced after direct inside stored heap =>
    exact ⟨by simp [inside], represents_heap_eq direct _ view _ heap
      (write_represents state direct view items index value represented stored)⟩

/-- Even uninitialized or invalid word observations outside the selected word
are unchanged. This applies to success, rejection and exhaustion alike. -/
theorem other_words_unchanged (version : Version) (state : State) (view : View) (index : Nat) (value : BitVec 32)
    (initial : state.valid = true) (cap : Writable state view) (indexBound : index < addressLimit)
    (offset : Nat) (apart : offset ≠ (view.address index).offset)
    (result : Except Fault Value) (after : State)
    (observed : (program version).run (arguments view index value) state = (result, after)) :
    load after (.pointer (.pointer true false word) ⟨view.allocation, offset⟩) =
      load state (.pointer (.pointer true false word) ⟨view.allocation, offset⟩) := by
  obtain ⟨actual, final, ran, safe⟩ := replace_safe version state view index value initial cap indexBound
  obtain ⟨rfl, rfl⟩ := Prod.mk.inj (ran.symm.trans observed)
  cases safe.effect with
  | exhausted _ heap | rejected _ _ heap => exact load_eq_of_lookup _ _ _ _ _ _ (by rw [heap])
  | replaced _ direct _ stored heap =>
    exact (load_eq_of_lookup direct _ _ _ _ _ (by rw [heap])).trans
      (write_offset_frame state direct view index offset value stored apart)

end Compiler.Tutorial.Buffer
