/-
// Copyright (C) 2026 OKcontract Pte. Ltd.
// SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryEffects
import Compiler.ZigAir.ControlSafety

/-! Inductive preservation of the allocation-table invariant. This covers typed
cell contents, aligned separated regions, and lifetime/address bounds.
It does not assert that stored pointers are live or refine a native allocator. -/
namespace Compiler.ZigAir.Memory

private def CellValid (nextId nextAddress : Nat) (entry : Nat × Allocation) : Prop :=
  entry.1 < nextId ∧ 0 < entry.2.base ∧ ∃ layout,
    entry.2.type.layout = some layout ∧ entry.2.base % layout.alignment = 0 ∧
    entry.2.base + layout.bytes ≤ nextAddress ∧
    entry.2.cells.valid entry.2.type = true

private theorem valid_iff (state : State) : state.valid = true ↔
    state.nextAddress ≤ addressLimit ∧
    (∀ entry ∈ state.heap, CellValid state.nextId state.nextAddress entry) ∧
    state.heap.Pairwise (fun a b => separated a b = true) := by
  simp only [State.valid, Bool.and_eq_true, decide_eq_true_eq, List.all_eq_true]
  rw [and_assoc]
  apply and_congr Iff.rfl
  apply and_congr _ Iff.rfl
  apply forall_congr'
  intro entry
  apply forall_congr'
  intro _
  rcases entry with ⟨id, cell⟩
  cases shaped : cell.type.layout <;> simp [CellValid, shaped, and_assoc]

theorem layout_alignment_positive (type : Ty) (layout : Layout)
    (shaped : type.layout = some layout) : 0 < layout.alignment := by
  cases type with
  | scalar type =>
    cases type with
    | int signed width =>
      unfold Ty.layout Ty.leafLayout at shaped
      split at shaped <;> simp_all <;> subst layout <;> decide
    | bool => cases shaped; decide
    | unit => cases shaped; decide
  | optionalScalar child =>
    cases child with
    | int signed width =>
      cases signed <;> simp only [Ty.layout, Ty.leafLayout] at shaped
      · split at shaped <;> simp_all <;> subst layout <;> decide
      · split at shaped <;> simp_all <;> subst layout <;> decide
    | bool | unit => cases shaped
  | optionalObject child captured =>
    have checked : ∀ payload, optionalLayout payload captured = some layout → 0 < layout.alignment := by
      intro payload accepted
      cases payload with
      | none => cases accepted
      | some region =>
        simp only [optionalLayout, bind, Option.bind] at accepted
        split at accepted
        · rename_i geometry
          cases accepted
          exact geometry.2.1
        · contradiction
    cases child <;> simp only [Ty.layout] at shaped
    all_goals first
      | contradiction
      | exact checked _ shaped
      | (split at shaped
         · rename_i same
           cases shaped
           rw [same]
           decide
         · contradiction)
  | pointer => cases shaped; decide
  | slice => cases shaped; decide
  | record _ captured =>
    simp only [Ty.layout] at shaped
    split at shaped
    · cases shaped; assumption
    · contradiction
  | aggregate _ captured fields =>
    simp only [Ty.layout] at shaped
    split at shaped
    · rename_i accepted
      cases shaped
      simp only [checkFields, Bool.and_eq_true, decide_eq_true_eq] at accepted
      exact accepted.1.1.2
    · contradiction
  | array length child =>
    cases h : child.layout with
    | none => simp [Ty.layout, h] at shaped
    | some childLayout =>
      simp [Ty.layout, h] at shaped
      subst layout
      exact layout_alignment_positive child childLayout h
termination_by structural type

private theorem align_up (cursor alignment : Nat) (positive : 0 < alignment) :
    (cursor + (alignment - cursor % alignment) % alignment) % alignment = 0 := by
  have small := Nat.mod_lt cursor positive
  by_cases zero : cursor % alignment = 0
  · simp [zero]
  · have remainder : (alignment - cursor % alignment) % alignment = alignment - cursor % alignment :=
      Nat.mod_eq_of_lt (by omega)
    rw [remainder, Nat.add_mod, remainder]
    rw [Nat.add_sub_of_le (Nat.le_of_lt small)]
    exact Nat.mod_self alignment

theorem allocate_preserves_valid (state : State) (child : Ty) (value : Value) (after : State)
    (success : allocate state child = .ok (value, after)) : after.valid = true := by
  unfold allocate at success
  split at success
  · contradiction
  · rename_i initial
    have initial : state.valid = true := by simpa using initial
    cases shaped : child.layout with
    | none => simp [shaped] at success
    | some layout =>
      simp only [shaped] at success
      split at success
      · contradiction
      · rename_i fits
        have eq := Except.ok.inj success
        cases eq
        rcases valid_iff state |>.mp initial with ⟨bounded, cells, disjoint⟩
        apply (valid_iff _).mpr
        refine ⟨by simp only; omega, ?_, ?_⟩
        · intro entry present
          rcases List.mem_cons.mp present with same | old
          · subst entry
            refine ⟨by simp, by simp only; omega, layout, shaped, ?_, by simp, ?_⟩
            · exact align_up _ _ (layout_alignment_positive child layout shaped)
            · rfl
          · rcases cells entry old with ⟨id, base, oldLayout, shape, aligned, extent, contents⟩
            exact ⟨by dsimp; omega, base, oldLayout, shape, aligned, by dsimp; omega, contents⟩
        · apply List.pairwise_cons.mpr
          refine ⟨?_, disjoint⟩
          intro entry present
          rcases cells entry present with ⟨id, _, oldLayout, shape, _, extent, _⟩
          simp only [separated, shaped, shape, Bool.and_eq_true, decide_eq_true_eq]
          exact ⟨by omega, Or.inr (by omega)⟩

theorem cleanup_preserves_valid (mark : Nat) (state : State) (initial : state.valid = true) :
    (cleanup mark state).valid = true := by
  rcases valid_iff state |>.mp initial with ⟨bounded, cells, disjoint⟩
  apply (valid_iff _).mpr
  exact ⟨bounded, fun entry present => cells entry (List.mem_filter.mp present).1,
    disjoint.filter _⟩

/-- Successful writes change only storage. Partial initialization remains typed
and does not alter the allocation's layout, permissions or lifetime. -/
theorem writeCell_preserves_shape (cell : Allocation) (offset : Nat) (value : Value) (after : Allocation)
    (initial : cell.cells.valid cell.type = true) (success : writeCell cell offset value = .ok after) :
    ∃ cells, after = { cell with cells := cells } ∧ cells.valid cell.type = true := by
  rcases writeCell_success cell offset value after success with ⟨contents, written, rfl⟩
  exact ⟨contents, rfl, Cells.write_preserves_valid cell.cells cell.type offset value contents initial written⟩

private theorem lookup_of_mem (heap : Heap) (id : Nat) (cell : Allocation)
    (disjoint : heap.Pairwise (fun a b => separated a b = true))
    (present : (id, cell) ∈ heap) : heap.lookup id = some cell := by
  induction heap with
  | nil => contradiction
  | cons entry tail ih =>
    rcases entry with ⟨key, value⟩
    rcases List.pairwise_cons.mp disjoint with ⟨apart, tailValid⟩
    rcases List.mem_cons.mp present with same | old
    · cases same
      simp only [Heap.lookup_cons, ite_true]
    · have different : key ≠ id := by
        have h := apart (id, cell) old
        simp only [separated, Bool.and_eq_true, decide_eq_true_eq] at h
        exact h.1
      simpa only [Heap.lookup_cons, ite_eq_right different] using ih tailValid old

/-- Valid memory has unique lifetime identities, so membership determines the
exact lookup rather than merely the first of potentially aliased entries. -/
theorem lookup_of_mem_valid (state : State) (id : Nat) (cell : Allocation)
    (valid : state.valid = true) (present : (id, cell) ∈ state.heap) :
    state.heap.lookup id = some cell :=
  lookup_of_mem state.heap id cell ((valid_iff state).mp valid).2.2 present

theorem replace_typed_preserves_valid (state : State) (id : Nat) (cell : Allocation) (contents : Cells)
    (initial : state.valid = true) (found : state.heap.lookup id = some cell)
    (typed : contents.valid cell.type = true) :
    ({ state with heap := state.heap.replace id { cell with cells := contents } } : State).valid = true := by
  rcases valid_iff state |>.mp initial with ⟨bounded, cells, disjoint⟩
  let replace := fun entry : Nat × Allocation =>
    if entry.1 = id then (id, { cell with cells := contents }) else entry
  have sameCell : ∀ entry ∈ state.heap, entry.1 = id → entry.2 = cell := by
    rintro ⟨key, old⟩ present selected
    dsimp at selected
    subst key
    exact Option.some.inj ((lookup_of_mem state.heap id old disjoint present).symm.trans found)
  have footprint : ∀ entry ∈ state.heap,
      (replace entry).1 = entry.1 ∧ (replace entry).2.type = entry.2.type ∧
      (replace entry).2.base = entry.2.base := by
    intro entry present
    by_cases selected : entry.1 = id
    · simp [replace, selected, sameCell entry present selected]
    · simp [replace, selected]
  apply (valid_iff _).mpr
  refine ⟨bounded, ?_, ?_⟩
  · intro entry present
    rcases List.mem_map.mp present with ⟨old, oldMem, rfl⟩
    change CellValid state.nextId state.nextAddress (replace old)
    by_cases selected : old.1 = id
    · rcases cells old oldMem with ⟨lifetime, base, layout, shaped, aligned, extent, _⟩
      have same := sameCell old oldMem selected
      simp only [replace, ite_eq_left selected, CellValid]
      refine ⟨by omega, ?_, layout, ?_, ?_, ?_, ?_⟩
      · simpa only [same] using base
      · simpa only [same] using shaped
      · simpa only [same] using aligned
      · simpa only [same] using extent
      · exact typed
    · simpa only [replace, ite_eq_right selected] using cells old oldMem
  · change (state.heap.map replace).Pairwise _
    apply List.pairwise_map.mpr
    apply disjoint.imp_of_mem
    intro a b aMem bMem apart
    rcases footprint a aMem with ⟨aId, aType, aBase⟩
    rcases footprint b bMem with ⟨bId, bType, bBase⟩
    simpa only [separated, aId, aType, aBase, bId, bType, bBase] using apart

theorem store_preserves_valid (state : State) (pointer value : Value) (after : State)
    (initial : state.valid = true) (success : store state pointer value = .ok after) : after.valid = true := by
  rcases store_success state pointer value after success with
    ⟨_, _, address, layout, cell, contents, _, _, _, accessed, written, rfl⟩
  have found := (access_success_region state address layout true cell accessed).1
  have cellValid := (valid_iff state |>.mp initial).2.1 (address.allocation, cell)
    (Heap.lookup_mem state.heap address.allocation cell found)
  rcases cellValid with ⟨_, _, _, _, _, _, contentsValid⟩
  exact replace_typed_preserves_valid state address.allocation cell contents initial found
    (Cells.write_preserves_valid cell.cells cell.type address.offset value contents contentsValid written)

theorem invalidate_valid (state : State) (writable : Bool) (child : Ty) (address : Address) (after : State)
    (initial : state.valid = true) (executed : invalidate state writable child address = .ok after) : after.valid = true := by
  obtain ⟨_, layout, cell, _, accessed, _, rfl⟩ := invalidate_success state writable child address after executed
  have found := (access_success_region state address layout true cell accessed).1
  have present := Heap.lookup_mem state.heap address.allocation cell found
  have typed : cell.cells.valid cell.type = true := by
    simp only [State.valid, Bool.and_eq_true, decide_eq_true_eq, List.all_eq_true] at initial
    have entry := initial.1.2 (address.allocation, cell) present
    cases shaped : cell.type.layout <;> simp_all
  exact replace_typed_preserves_valid state address.allocation cell _ initial found
    (Cells.forget_valid cell.cells cell.type address.offset layout.bytes typed)

namespace ByteRange

theorem copyByte_valid (state after : State) (source target : Address) (index : Nat)
    (initial : state.valid = true) (copied : copyByte state source target index = .ok after) :
    after.valid = true := by
  rcases copyByte_success copied with ⟨bits, _, stored⟩ | ⟨_, forgotten⟩
  · exact store_preserves_valid _ _ _ _ initial stored
  · exact invalidate_valid _ _ _ _ _ initial forgotten

theorem copyLoop_valid (state : State) (source target : Address) (index count : Nat)
    (initial : state.valid = true) : (copyLoop state source target index count).2.valid = true :=
  copyLoop_preserves (fun s => s.valid = true) (fun valid copied => copyByte_valid _ _ _ _ _ valid copied)
    state source target index count initial

theorem copy_valid (state : State) (target input : Value) (initial : state.valid = true) :
    (copy state target input).2.valid = true :=
  copy_preserves (fun s => s.valid = true) (fun valid copied => copyByte_valid _ _ _ _ _ valid copied)
    state target input initial

theorem copyBackward_valid (state : State) (source target : Address) (count : Nat)
    (initial : state.valid = true) : (copyBackward state source target count).2.valid = true :=
  copyBackward_preserves (fun s => s.valid = true) (fun valid copied => copyByte_valid _ _ _ _ _ valid copied)
    state source target count initial

theorem move_valid (state : State) (target input : Value) (initial : state.valid = true) :
    (move state target input).2.valid = true :=
  move_preserves (fun s => s.valid = true) (fun valid copied => copyByte_valid _ _ _ _ _ valid copied)
    state target input initial

end ByteRange

end Compiler.ZigAir.Memory

namespace Compiler.ZigAir.MemoryAir
open Memory

private theorem bind_success {α β : Type} (first : Except Fault α) (next : α → Except Fault β)
    (result : β) (success : first >>= next = .ok result) :
    ∃ value, first = .ok value ∧ next value = .ok result := by
  cases first <;> simp_all [bind, Except.bind]

theorem Prim.transition_preserves_valid (prim : Prim) (args : List Value) (env : Env)
    (state : State) (value : Value) (after : State) (initial : state.valid = true)
    (success : prim.transition args env state = .ok (value, after)) : after.valid = true := by
  cases prim with
  | alloc child => exact allocate_preserves_valid state child value after success
  | store pointer operand =>
    rcases bind_success (pointer.eval env) _ _ success with ⟨p, _, rest⟩
    rcases bind_success (operand.eval env) _ _ rest with ⟨v, _, rest⟩
    rcases bind_success (Memory.store state p v) _ _ rest with ⟨stored, written, same⟩
    cases (Prod.mk.inj (Except.ok.inj same)).2
    exact store_preserves_valid state p v after initial written
  | wordByteStore order pointer operand =>
    rcases bind_success (pointer.eval env) _ _ success with ⟨p, _, rest⟩
    rcases bind_success (operand.eval env) _ _ rest with ⟨v, _, rest⟩
    rcases bind_success (ByteAccess.write order state p v) _ _ rest with ⟨stored, written, same⟩
    cases (Prod.mk.inj (Except.ok.inj same)).2
    obtain ⟨wordPointer, wordValue, effect⟩ := ByteAccess.write_store order state after p v written
    exact store_preserves_valid state wordPointer wordValue after initial effect
  | _ =>
    simp only [Prim.transition, bind, Except.bind] at success
    repeat' split at success
    all_goals first
      | contradiction
      | (cases (Prod.mk.inj (Except.ok.inj success)).2; exact initial)

theorem Prim.preserves_valid (prim : Prim) (args : List Value) (env : Env)
    (state : State) (initial : state.valid = true) : (prim.eval args env state).2.valid = true := by
  by_cases bulk : ∃ target source, prim = .copyBytes target source
  · obtain ⟨target, source, rfl⟩ := bulk
    simp only [Prim.eval, evalByteTransfer]
    cases target.eval env <;> cases source.eval env <;> simp only
    all_goals first | exact initial | exact ByteRange.copy_valid _ _ _ initial
  by_cases moving : ∃ target source, prim = .moveBytes target source
  · obtain ⟨target, source, rfl⟩ := moving
    simp only [Prim.eval, evalByteTransfer]
    cases target.eval env <;> cases source.eval env <;> simp only
    all_goals first | exact initial | exact ByteRange.move_valid _ _ _ initial
  have atomic : ∀ target source, prim ≠ .copyBytes target source := by simpa using bulk
  have atomicMove : ∀ target source, prim ≠ .moveBytes target source := by simpa using moving
  have equation : prim.eval args env state =
      match prim.transition args env state with
      | .ok (value, after) => (.ok value, after)
      | .error fault => (.error fault, state) := by
    cases prim <;> first | rfl | exact False.elim (atomic _ _ rfl) | exact False.elim (atomicMove _ _ rfl)
  rw [equation]
  cases step : prim.transition args env state with
  | error fault => exact initial
  | ok result =>
    rcases result with ⟨value, after⟩
    exact prim.transition_preserves_valid args env state value after initial step

/-- All finite bind/branch/block/jump/return paths, including every fault. -/
theorem Code.preserves_valid (code : Code) (args : List Value) (env : Env)
    (state : State) (initial : state.valid = true) :
    (code.eval semantics args env state).state.valid = true :=
  Control.Code.preserves semantics (fun state => state.valid = true) Prim.preserves_valid
    code args env state initial

/-- Invocation type checks and stack cleanup preserve the same invariant on
success, source/memory/resource failure, malformed return and escaping jump. -/
theorem Program.preserves_valid (program : Program) (args : List Value)
    (state : State) (initial : state.valid = true) : (program.run args state).2.valid = true := by
  unfold Program.run
  split
  · have bodyValid := Code.preserves_valid program.body args (fun _ => none) state initial
    cases result : program.body.eval semantics args (fun _ => none) state <;>
      simp only [result, Control.Outcome.state] at bodyValid <;>
      exact cleanup_preserves_valid state.nextId _ bodyValid
  · exact initial

end Compiler.ZigAir.MemoryAir
