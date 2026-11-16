/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryBorrowedWords
import Compiler.ZigAir.MemorySliceLaws
import Compiler.ZigAir.MemoryVerificationFacts
import Compiler.ZigAir.MemoryReadTyping

/-! Initialization and slice rules for any client using a writable word view.
Initialization, writable extent and framing remain distinct predicates. -/
namespace Compiler.ZigAir.Memory.WordArray

@[simp] theorem scalar_word_valid (bits : BitVec 32) :
    (Scalar.Value.int false 32 bits.toNat).valid = true := number_valid bits

@[simp] theorem scalar_word_typed (bits : BitVec 32) :
    (Value.scalar (.int false 32 bits.toNat)).hasType word = true := number_typed bits

@[simp] theorem slice_length (view : View) :
    MemoryAir.sliceLength view.slice = .ok (.scalar (.int false 64 view.length)) := rfl

theorem View.slice_valid (view : View) (bound : view.length < addressLimit) :
    view.slice.valid = true := by simp [View.slice, Value.valid, bound]

theorem View.slice_typed (view : View) (bound : view.length < addressLimit) :
    view.slice.hasType (.slice true word) = true := by
  simpa [Value.hasType, Value.type, View.slice] using View.slice_valid view bound

/-- Successful selection determines the pointer independently of a client's
capability proof. This can normalize an SSA result before discharging safety. -/
theorem slice_selected (state : State) (view : View) (index : Nat) (pointer : Value)
    (selected : sliceElementPointer state view.slice index = .ok pointer) : pointer = view.pointer index := by
  obtain ⟨_, _, layout, shape, _, equation⟩ :=
    sliceElementPointer_address state true word (view.address 0) view.length index pointer selected
  have same : layout = ⟨4, 4⟩ := Option.some.inj shape.symm
  subst layout
  simpa [View.pointer, View.address, Nat.add_mul] using equation

def Initialized (state : State) (view : View) : Prop := ∃ items, Represents state view items

theorem loaded_word (state : State) (view : View) (index : Nat) (value : Value)
    (loaded : load state (view.pointer index) = .ok value) : ∃ bits : BitVec 32, value = number bits :=
  value.word_value (load_hasType state true false word (view.address index) value loaded)

theorem stored_word_type (state after : State) (view : View) (index : Nat) (value : Value)
    (stored : store state (view.pointer index) value = .ok after) : value.hasType word = true := by
  obtain ⟨many, child, address, _, _, _, pointer, typed, _⟩ := store_success state _ value after stored
  have same : many = false ∧ child = word := by simpa [View.pointer] using (Value.pointer.inj pointer).1.symm
  simpa only [same.2] using typed

theorem Initialized.read (initialized : Initialized state view) (index : Nat) (inside : index < view.length) :
    ∃ value, load state (view.pointer index) = .ok (number value) := by
  obtain ⟨items, length, represented⟩ := initialized
  exact ⟨items[index]'(by omega), represented index (by omega)⟩

theorem Initialized.read_slice (initialized : Initialized state view) (index : Nat) (pointer : Value)
    (valid : state.valid = true) (cap : Writable state view) (inside : index < view.length)
    (selected : sliceElementPointer state view.slice index = .ok pointer) :
    ∃ value, load state pointer = .ok (number value) := by
  have same := Except.ok.inj (selected.symm.trans (slice_element state view index valid cap inside))
  subst pointer
  exact initialized.read index inside

theorem Initialized.stack (initialized : Initialized before view) (frame : StackFrame before after) :
    Initialized after view := by
  obtain ⟨items, represented⟩ := initialized
  exact ⟨items, represented.stack frame⟩

theorem Initialized.allocated (initialized : Initialized state view) (valid : state.valid = true)
    (allocated : allocate state type = .ok (pointer, after)) : Initialized after view :=
  initialized.stack ((StackFrame.refl state valid).allocate type pointer after allocated)

theorem Initialized.store_other (initialized : Initialized state view)
    (write many : Bool) (child : Ty) (address : Address) (value : Value)
    (apart : view.allocation ≠ address.allocation)
    (stored : store state (.pointer (.pointer write many child) address) value = .ok after) :
    Initialized after view := by
  obtain ⟨items, represented⟩ := initialized
  exact ⟨items, represented.store_other write many child address value apart stored⟩

theorem Initialized.store_word (initialized : Initialized state view) (index : Nat) (value : BitVec 32)
    (stored : store state (view.pointer index) (number value) = .ok after) : Initialized after view := by
  obtain ⟨items, represented⟩ := initialized
  exact ⟨items.set index value, write_represents state after view items index value represented stored⟩

theorem Initialized.store_value (initialized : Initialized state view) (index : Nat) (value : Value)
    (stored : store state (view.pointer index) value = .ok after) : Initialized after view := by
  obtain ⟨bits, rfl⟩ := value.word_value (stored_word_type _ _ _ _ _ stored)
  exact initialized.store_word index bits stored

theorem BorrowedFrame.store_value (frame : BorrowedFrame view before current) (index : Nat) (value : Value)
    (older : view.allocation < before.nextId) (inside : index < view.length)
    (stored : store current (view.pointer index) value = .ok after) : BorrowedFrame view before after := by
  obtain ⟨bits, rfl⟩ := value.word_value (stored_word_type _ _ _ _ _ stored)
  exact frame.store_word index bits older inside stored

theorem Initialized.cleanup (initialized : Initialized state view) (older : view.allocation < mark) :
    Initialized (Memory.cleanup mark state) view := by
  obtain ⟨items, length, represented⟩ := initialized
  exact ⟨items, length, fun index inside =>
    (load_eq_of_lookup state (Memory.cleanup mark state) true false word (view.address index)
      (cleanup_lookup_older state mark view.allocation older)).trans (represented index inside)⟩

grind_pattern Initialized.store_other => Initialized state view,
  StoreStep state (.pointer (.pointer write many child) address) value after
grind_pattern Initialized.store_word => Initialized state view,
  StoreStep state (view.pointer index) (number value) after
grind_pattern slice_element => Writable state view, sliceElementPointer state view.slice index
grind_pattern Initialized.read => Initialized state view, load state (view.pointer index)
grind_pattern Initialized.read_slice => Initialized state view,
  sliceElementPointer state view.slice index, (Except.ok pointer : Except Fault Value)
grind_pattern Initialized.store_value => Initialized state view,
  StoreStep state (view.pointer index) value after
grind_pattern BorrowedFrame.store_value => BorrowedFrame view before current,
  StoreStep current (view.pointer index) value after

end Compiler.ZigAir.Memory.WordArray
