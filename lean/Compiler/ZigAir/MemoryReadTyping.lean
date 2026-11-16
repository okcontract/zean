/-
// Copyright (C) 2026 OKcontract Pte. Ltd.
// SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryEffects

namespace Compiler.ZigAir.Memory

theorem Value.boolean_value (value : Value) (typed : value.hasType (.scalar .bool) = true) :
    ∃ flag : Bool, value = .scalar (.bool flag) := by
  have same : value.type = .scalar .bool := of_decide_eq_true (Bool.and_eq_true_iff.mp typed).1
  cases value with
  | scalar scalar => cases scalar with
    | bool flag => exact ⟨flag, rfl⟩
    | int | unit => simp [Value.type, Scalar.Value.type] at same
  | optionalScalar | optionalObject => simp [Value.type] at same
  | pointer type address =>
    change type = .scalar .bool at same
    subst type
    simp [Value.hasType, Value.valid] at typed
  | slice type address length =>
    change type = .scalar .bool at same
    subst type
    simp [Value.hasType, Value.valid] at typed

theorem Value.unsigned_value (value : Value) (width : Nat)
    (typed : value.hasType (.scalar (.int false width)) = true) :
    ∃ number : Int, value = .scalar (.int false width number) ∧ 0 ≤ number ∧ number < 2 ^ width := by
  have same : value.type = .scalar (.int false width) :=
    of_decide_eq_true (Bool.and_eq_true_iff.mp typed).1
  cases value with
  | scalar value =>
    cases value with
    | unit | bool => simp [Value.type, Scalar.Value.type] at same
    | int signed bits number =>
      simp only [Value.type, Scalar.Value.type, Ty.scalar.injEq, Scalar.Ty.int.injEq] at same
      obtain ⟨rfl, rfl⟩ := same
      refine ⟨number, rfl, ?_⟩
      simp only [Value.hasType, Value.type, Scalar.Value.type, decide_true, Bool.true_and,
        Value.valid, Scalar.Value.valid, Scalar.Ty.contains, Scalar.Ty.lower, Scalar.Ty.upper] at typed
      exact of_decide_eq_true typed
  | optionalScalar child payload | optionalObject child _ payload =>
    simp [Value.hasType, Value.type] at typed
  | pointer type address =>
    change type = .scalar (.int false width) at same
    subst type
    simp [Value.hasType, Value.valid] at typed
  | slice type address length =>
    change type = .scalar (.int false width) at same
    subst type
    simp [Value.hasType, Value.valid] at typed

theorem Value.usize_value (value : Value) (typed : value.hasType usize = true) :
    ∃ number, value = .scalar (.int false 64 number) := by
  obtain ⟨number, same, _, _⟩ := value.unsigned_value 64 typed
  exact ⟨number, same⟩

/-- A successful sparse read checks every stored leaf, including the unsigned
length of a reconstructed slice. No initial heap-validity premise is required. -/
theorem Cells.read_hasType (cells : Cells) (owner : Ty) (offset : Nat) (wanted : Ty) (value : Value)
    (loaded : cells.read owner offset wanted = .ok value) : value.hasType wanted = true := by
  unfold Cells.read at loaded
  split at loaded
  · contradiction
  · cases wanted with
    | array | record | aggregate => contradiction
    | scalar type => exact cells.readLeaf_hasType owner offset (.scalar type) value loaded
    | optionalScalar child => exact cells.readLeaf_hasType owner offset (.optionalScalar child) value loaded
    | optionalObject child layout => exact cells.readLeaf_hasType owner offset (.optionalObject child layout) value loaded
    | pointer writable many child => exact cells.readLeaf_hasType owner offset (.pointer writable many child) value loaded
    | slice writable child =>
      cases pointerRead : cells.readLeaf owner offset (.pointer writable true child) with
      | error fault => simp only [pointerRead, bind, Except.bind] at loaded; cases loaded
      | ok pointer =>
        simp only [pointerRead, bind, Except.bind] at loaded
        cases pointer with
        | scalar | optionalScalar | optionalObject | slice => cases loaded
        | pointer type address =>
          cases lengthRead : cells.readLeaf owner (offset + 8) usize with
          | error fault => simp only [lengthRead] at loaded; cases loaded
          | ok length =>
            obtain ⟨number, rfl⟩ := Value.usize_value length
              (cells.readLeaf_hasType owner (offset + 8) usize length lengthRead)
            have checked := cells.readLeaf_hasType owner (offset + 8) usize (.scalar (.int false 64 number)) lengthRead
            simp only [lengthRead] at loaded
            have same := Except.ok.inj loaded
            subst value
            change decide (0 ≤ number ∧ number < (2 : Int) ^ 64) = true at checked
            have bounds := of_decide_eq_true checked
            simp only [Value.hasType, Value.type, Value.valid, decide_true, Bool.true_and]
            change decide (number.toNat < addressLimit) = true
            apply decide_eq_true
            dsimp [addressLimit]
            omega

theorem load_hasType (state : State) (writable many : Bool) (child : Ty) (address : Address) (value : Value)
    (loaded : load state (.pointer (.pointer writable many child) address) = .ok value) :
    value.hasType child = true := by
  cases shaped : child.layout with
  | none => simp [load, shaped] at loaded
  | some layout =>
    cases accessed : access state address layout false with
    | error fault => simp [load, shaped, accessed, bind, Except.bind] at loaded
    | ok cell =>
      apply cell.cells.read_hasType cell.type address.offset child value
      simpa only [load, shaped, accessed, bind, Except.bind, readCell] using loaded

/-- A successful read retains its declared type even before the pointer's
address has been resolved by the caller's spatial contract. -/
theorem load_hasType_of_pointer (state : State) (pointer value : Value)
    (writable many : Bool) (child : Ty)
    (typed : pointer.hasType (.pointer writable many child) = true)
    (loaded : load state pointer = .ok value) : value.hasType child = true := by
  have type := (Bool.and_eq_true_iff.mp typed).1
  have valid := (Bool.and_eq_true_iff.mp typed).2
  simp only [decide_eq_true_eq] at type
  cases pointer with
  | scalar | optionalScalar | optionalObject => cases type
  | slice ty address length =>
    simp only [Value.type] at type
    subst ty
    cases valid
  | pointer ty address =>
    simp only [Value.type] at type
    subst ty
    exact load_hasType state writable many child address value loaded

/-- A checked slice read exposes the exact typed pointer and unsigned length
leaves. Both partial-field update laws use this same reconstruction boundary. -/
theorem Cells.read_slice_parts (cells : Cells) (owner : Ty) (offset : Nat) (writable : Bool) (child : Ty)
    (address : Address) (length : Nat)
    (loaded : cells.read owner offset (.slice writable child) = .ok (.slice (.slice writable child) address length)) :
    acceptsView owner offset (.slice writable child) = true ∧
      cells.readLeaf owner offset (.pointer writable true child) = .ok (.pointer (.pointer writable true child) address) ∧
      cells.readLeaf owner (offset + 8) usize = .ok (.scalar (.int false 64 length)) := by
  by_cases view : acceptsView owner offset (.slice writable child) = true
  · simp only [Cells.read, view, Bool.not_true, Bool.false_eq_true, ↓reduceIte] at loaded
    cases pointerRead : cells.readLeaf owner offset (.pointer writable true child) with
    | error fault => simp only [pointerRead, bind, Except.bind] at loaded; cases loaded
    | ok pointer =>
      simp only [pointerRead, bind, Except.bind] at loaded
      cases pointer with
      | scalar | optionalScalar | optionalObject | slice => cases loaded
      | pointer type data =>
        have pointerTyped := cells.readLeaf_hasType owner offset (.pointer writable true child) (.pointer type data) pointerRead
        have pointerType : type = .pointer writable true child :=
          of_decide_eq_true (Bool.and_eq_true_iff.mp pointerTyped).1
        subst type
        cases lengthRead : cells.readLeaf owner (offset + 8) usize with
        | error fault => simp only [lengthRead] at loaded; cases loaded
        | ok value =>
          obtain ⟨number, rfl⟩ := Value.usize_value value (cells.readLeaf_hasType owner (offset + 8) usize value lengthRead)
          have checked := cells.readLeaf_hasType owner (offset + 8) usize (.scalar (.int false 64 number)) lengthRead
          simp only [lengthRead] at loaded
          have same := Value.slice.inj (Except.ok.inj loaded)
          change decide (0 ≤ number ∧ number < (2 : Int) ^ 64) = true at checked
          have bounds := of_decide_eq_true checked
          have numberEq : number = (length : Int) := by omega
          exact ⟨view, by simp only [same.2.1], by simp only [numberEq]⟩
  · have rejected := Bool.eq_false_iff.mpr view
    simp only [Cells.read, rejected, Bool.not_false, ↓reduceIte] at loaded
    cases loaded

theorem Cells.read_slice_of_parts (cells : Cells) (owner : Ty) (offset : Nat) (writable : Bool) (child : Ty)
    (address : Address) (length : Nat) (view : acceptsView owner offset (.slice writable child) = true)
    (pointerRead : cells.readLeaf owner offset (.pointer writable true child) = .ok (.pointer (.pointer writable true child) address))
    (lengthRead : cells.readLeaf owner (offset + 8) usize = .ok (.scalar (.int false 64 length))) :
    cells.read owner offset (.slice writable child) = .ok (.slice (.slice writable child) address length) := by
  simp only [Cells.read, view, Bool.not_true, Bool.false_eq_true, ↓reduceIte, pointerRead, lengthRead, bind, Except.bind,
    Int.toNat_natCast]

end Compiler.ZigAir.Memory
