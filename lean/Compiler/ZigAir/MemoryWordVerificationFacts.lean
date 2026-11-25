/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryVerificationFacts
import Compiler.ZigAir.MemoryWordCopyFrame

/-! Fault-exclusion facts for the optional word-buffer contracts. -/
namespace Compiler.ZigAir.Memory

theorem Value.word_value (value : Value) (typed : value.hasType WordArray.word = true) :
    ∃ bits : BitVec 32, value = WordArray.number bits := by
  have same : value.type = WordArray.word := of_decide_eq_true (Bool.and_eq_true_iff.mp typed).1
  have valid := MemoryAir.value_valid_of_hasType value _ typed
  cases value with
  | scalar value =>
    cases value with
    | unit | bool => simp [Value.type, Scalar.Value.type, WordArray.word] at same
    | int signed width number =>
      simp only [Value.type, Scalar.Value.type, WordArray.word, Ty.scalar.injEq, Scalar.Ty.int.injEq] at same
      obtain ⟨rfl, rfl⟩ := same
      have bounds : 0 ≤ number ∧ number < 2 ^ 32 := of_decide_eq_true valid
      refine ⟨BitVec.ofNat 32 number.toNat, ?_⟩
      have small : number.toNat < 2 ^ 32 := by omega
      simp [WordArray.number, BitVec.toNat_ofNat, Nat.mod_eq_of_lt small, Int.toNat_of_nonneg bounds.1]
  | errorValue | optionalScalar | optionalObject => simp [Value.hasType, Value.type, WordArray.word] at typed
  | pointer type address =>
    change type = WordArray.word at same
    subst type
    simp [Value.hasType, Value.valid, WordArray.word] at typed
  | slice type address length =>
    change type = WordArray.word at same
    subst type
    simp [Value.hasType, Value.valid, WordArray.word] at typed

theorem WordArray.write_value_total (state : State) (view : WordArray.View) (index : Nat)
    (value : Value) (typed : value.hasType WordArray.word = true)
    (valid : state.valid = true) (cap : WordArray.Writable state view) (inside : index < view.length) :
    ∃ after, store state (view.pointer index) value = .ok after := by
  obtain ⟨bits, rfl⟩ := value.word_value typed
  exact WordArray.write_total state view index bits valid cap inside

theorem WordArray.write_value_no_fault (state : State) (view : WordArray.View) (index : Nat)
    (value : Value) (fault : Fault) (typed : value.hasType WordArray.word = true)
    (valid : state.valid = true) (cap : WordArray.Writable state view) (inside : index < view.length)
    (failed : store state (view.pointer index) value = .error fault) : False := by
  obtain ⟨after, stored⟩ := WordArray.write_value_total state view index value typed valid cap inside
  rw [stored] at failed
  contradiction

theorem WordArray.write_no_fault (state : State) (view : WordArray.View) (index : Nat)
    (value : BitVec 32) (fault : Fault)
    (valid : state.valid = true) (cap : WordArray.Writable state view) (inside : index < view.length)
    (failed : store state (view.pointer index) (WordArray.number value) = .error fault) : False := by
  obtain ⟨after, stored⟩ := WordArray.write_total state view index value valid cap inside
  rw [stored] at failed
  contradiction

end Compiler.ZigAir.Memory
