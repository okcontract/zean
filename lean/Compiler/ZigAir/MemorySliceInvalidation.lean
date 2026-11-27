/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryByteCopyContracts
import Compiler.ZigAir.MemoryWriteView

namespace Compiler.ZigAir.Memory.SliceInvalidation

structure Post (view : ReadView) (count : Nat) (before after : State) : Prop where
  valid : after.valid = true
  shape : before.heap.RetainsShape after.heap
  nextId : after.nextId = before.nextId
  nextAddress : after.nextAddress = before.nextAddress
  frame : ByteArray.HeapFrame ⟨view.address, view.length * view.layout.bytes⟩ before after
  cleared : ∀ i < count, load after (view.pointer i) = .error .uninitialized

private theorem invalidate_element {view : ReadView} {index : Nat}
    (cap : view.Writable before) (element : view.child = .scalar scalar) (inside : index < view.length) :
    ∃ after, invalidate before true view.child (view.addressAt index) = .ok after ∧
      load after (view.pointer index) = .error .uninitialized := by
  obtain ⟨cell, checked, accepted, declared⟩ := cap index inside
  let address := view.addressAt index
  let cells := cell.cells.forget address.offset view.layout.bytes
  let after := { before with heap := before.heap.replace address.allocation { cell with cells } }
  have erased : invalidate before true view.child address = .ok after :=
    invalidate_of_access _ _ _ _ cell view.shaped checked accepted
  have found := (access_success_region _ _ _ _ _ checked).1
  have readable : access before address view.layout false = .ok cell := access_write_read _ _ _ _ checked
  have changed := access_replace_cells before address view.layout false cell cells found
  have stillReadable : access after address view.layout false = .ok { cell with cells } := by
    simpa only [after, readable] using changed
  have forgotten : cells.lookup address.offset = none := by
    simp [cells, Cells.lookup_forget, view.positive]
  refine ⟨after, erased, ?_⟩
  change load after (.pointer (.pointer false false view.child) address) = _
  rw [load, view.shaped]
  simp only [stillReadable, bind, Except.bind, readCell]
  have acceptedScalar : acceptsView cell.type address.offset (.scalar scalar) = true := element ▸ accepted
  have declaredScalar : leafType cell.type address.offset = some (.scalar scalar) := element ▸ declared
  simp [element, Cells.read, Cells.readLeaf, acceptedScalar, declaredScalar, forgotten]

private theorem isolate_element {view : ReadView} (inside : index < view.length)
    (erased : invalidate before true view.child (view.addressAt index) = .ok after) :
    ByteArray.HeapFrame ⟨view.address, view.length * view.layout.bytes⟩ before after := by
  refine ⟨(invalidate_frame _ _ _ _ _ erased).2.2, ?_⟩
  intro child offset writable many outside
  have fits : (index + 1) * view.layout.bytes ≤ view.length * view.layout.bytes :=
    Nat.mul_le_mul_right _ (by omega)
  apply load_disjoint_after_invalidate before after true view.child (view.addressAt index)
    view.layout writable many child offset view.shaped erased
  intro position member
  have apart := outside position member
  simp only [ByteArray.Outside, ReadView.addressAt] at apart ⊢
  rw [Nat.add_mul, Nat.one_mul] at fits
  omega

private theorem retain_earlier {view : ReadView} (element : view.child = .scalar scalar)
    (earlier : previous < index)
    (erased : invalidate before true view.child (view.addressAt index) = .ok after) :
    load after (view.pointer previous) = load before (view.pointer previous) := by
  apply load_disjoint_after_invalidate before after true view.child (view.addressAt index) view.layout
    false false view.child (view.addressAt previous).offset view.shaped erased
  intro position member
  rw [element] at member
  change position ∈ [(view.addressAt previous).offset] at member
  cases List.mem_singleton.mp member
  left
  exact Nat.add_lt_add_left (Nat.mul_lt_mul_of_pos_right earlier view.positive) _

private theorem elements_total {view : ReadView} (element : view.child = .scalar scalar)
    (valid : state.valid = true) (cap : view.Writable state) (bounded : index + count ≤ view.length)
    (prior : ∀ i < index, load state (view.pointer i) = .error .uninitialized) :
    ∃ after, runElements state view.child view.address view.layout.bytes index count = (.ok (), after) ∧
      Post view (index + count) state after := by
  induction count generalizing state index with
  | zero =>
    exact ⟨state, rfl, valid, .refl _, rfl, rfl, .refl _ _, prior⟩
  | succ count ih =>
    obtain ⟨middle, erased, lost⟩ := invalidate_element cap element (by omega : index < view.length)
    have shape := invalidate_retains_shape _ _ _ _ _ erased
    have validMiddle := invalidate_valid _ _ _ _ _ valid erased
    have cleared : ∀ i < index + 1, load middle (view.pointer i) = .error .uninitialized := by
      intro i inside
      by_cases same : i = index
      · simpa only [same] using lost
      · have earlier : i < index := by omega
        exact (retain_earlier element earlier erased).trans (prior i earlier)
    obtain ⟨after, finished, post⟩ := ih validMiddle (cap.retained shape) (by omega) cleared
    obtain ⟨sameId, sameAddress, _⟩ := invalidate_frame _ _ _ _ _ erased
    refine ⟨after, ?_, post.valid, shape.trans post.shape, post.nextId.trans sameId,
      post.nextAddress.trans sameAddress, (isolate_element (by omega) erased).trans post.frame, ?_⟩
    · rw [runElements]
      change (match invalidate state true view.child (view.addressAt index) with
        | .error fault => (Except.error fault, state)
        | .ok next => runElements next view.child view.address view.layout.bytes (index + 1) count) = _
      rw [erased]
      exact finished
    · intro i inside
      exact post.cleared i (by omega)

/-- Executing a typed undefined fill keeps the allocation and forgets exactly
the destination's initialized scalar leaves. A zero-length view performs no
access, which includes a one-past or static empty slice. -/
theorem run_total {view : ReadView} (element : view.child = .scalar scalar)
    (valid : state.valid = true) (cap : view.Writable state) (width : view.length < addressLimit) :
    ∃ after, run state view.writeSlice = (.ok (), after) ∧ Post view view.length state after := by
  have bounded : 0 + view.length ≤ view.length := by simp
  obtain ⟨after, finished, post⟩ := elements_total element valid cap bounded
    (fun _ inside => False.elim (Nat.not_lt_zero _ inside))
  have typed : (Value.slice (.slice true view.child) view.address view.length).valid = true :=
    decide_eq_true width
  refine ⟨after, ?_, by simpa only [Nat.zero_add] using post⟩
  rw [ReadView.writeSlice]
  simpa only [run, typed, Bool.not_true, Bool.false_eq_true, ↓reduceIte,
    view.shaped, Nat.ne_of_gt view.positive] using finished

end Compiler.ZigAir.Memory.SliceInvalidation
