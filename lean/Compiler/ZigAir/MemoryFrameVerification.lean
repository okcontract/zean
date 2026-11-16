/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryStackFrameMutation
import Compiler.ZigAir.MemoryInvalidation

/-! Primitive rules for invocation-owned stack storage and caller writes.
Neither rule assumes a complete invocation or erases reached effects. -/
namespace Compiler.ZigAir.Memory

theorem StackFrame.store_local (frame : StackFrame before current) (write many : Bool) (child : Ty)
    (address : Address) (value : Value) (after : State) (fresh : before.nextId ≤ address.allocation)
    (stored : store current (.pointer (.pointer write many child) address) value = .ok after) :
    StackFrame before after := by
  have valid := store_preserves_valid current _ value after frame.valid stored
  obtain ⟨_, _, _, _, cell, contents, same, _, _, accessed, _, rfl⟩ := store_success current _ value after stored
  cases same
  have found := (access_success_region current address _ true cell accessed).1
  have stack := frame.native_cell address.allocation cell fresh found
  obtain ⟨locals, heap, owned⟩ := frame.extended
  have absent : before.heap.replace address.allocation { cell with cells := contents } = before.heap :=
    Heap.replace_absent _ _ _ (by
      intro entry member
      have older := StackFrame.older before frame.initial entry member
      omega)
  refine ⟨frame.initial, valid, frame.nextId,
    locals.replace address.allocation { cell with cells := contents }, ?_, ?_⟩
  · change (current.heap.replace _ _) = _
    rw [heap]
    simpa only [Heap.replace, List.map_append] using congrArg
      (locals.replace address.allocation { cell with cells := contents } ++ ·) absent
  · intro entry member
    obtain ⟨old, inside, replaced⟩ := List.mem_map.mp member
    by_cases selected : old.1 = address.allocation
    · simp only [ite_eq_left selected] at replaced
      rw [← replaced]
      exact ⟨stack, fresh⟩
    · simp only [ite_eq_right selected] at replaced
      rw [← replaced]
      exact owned old inside

theorem StackFrame.store_caller (frame : StackFrame before current) (write many : Bool) (child : Ty)
    (address : Address) (value : Value) (after : State) (older : address.allocation < before.nextId)
    (stored : store current (.pointer (.pointer write many child) address) value = .ok after) :
    ∃ direct, store before (.pointer (.pointer write many child) address) value = .ok direct ∧
      StackFrame direct after := by
  have valid := store_preserves_valid current _ value after frame.valid stored
  obtain ⟨_, _, _, layout, cell, contents, same, typed, shaped, accessed, written, rfl⟩ :=
    store_success current _ value after stored
  cases same
  have lookup : current.heap.lookup address.allocation = before.heap.lookup address.allocation := by
    rw [← cleanup_lookup_older current before.nextId address.allocation older, frame.cleanup_heap]
  have accessBefore : access before address layout true = .ok cell := by
    simpa only [access, lookup] using accessed
  have direct := store_of_access before child address layout cell contents value typed shaped accessBefore written
  refine ⟨_, direct, store_preserves_valid before _ value _ frame.initial direct, valid, frame.nextId, ?_⟩
  obtain ⟨locals, heap, owned⟩ := frame.extended
  have absent : locals.replace address.allocation { cell with cells := contents } = locals :=
    Heap.replace_absent _ _ _ (by
      intro entry member
      have recent := (owned entry member).2
      omega)
  refine ⟨locals, ?_, owned⟩
  change (current.heap.replace _ _) = _
  rw [heap]
  simpa only [Heap.replace, List.map_append] using congrArg
    (· ++ before.heap.replace address.allocation { cell with cells := contents }) absent

theorem StackFrame.invalidate_caller (frame : StackFrame before current) (child : Ty)
    (address : Address) (after : State) (older : address.allocation < before.nextId)
    (forgotten : invalidate current true child address = .ok after) :
    ∃ direct, invalidate before true child address = .ok direct ∧ StackFrame direct after := by
  have valid := invalidate_valid current true child address after frame.valid forgotten
  obtain ⟨_, layout, cell, shaped, accessed, view, rfl⟩ :=
    invalidate_success current true child address after forgotten
  have lookup : current.heap.lookup address.allocation = before.heap.lookup address.allocation := by
    rw [← cleanup_lookup_older current before.nextId address.allocation older, frame.cleanup_heap]
  have accessBefore : access before address layout true = .ok cell := by
    simpa only [access, lookup] using accessed
  have direct := invalidate_of_access before child address layout cell shaped accessBefore view
  refine ⟨_, direct, invalidate_valid before true child address _ frame.initial direct, valid, frame.nextId, ?_⟩
  obtain ⟨locals, heap, owned⟩ := frame.extended
  have absent : locals.replace address.allocation
      { cell with cells := cell.cells.forget address.offset layout.bytes } = locals :=
    Heap.replace_absent _ _ _ (by
      intro entry member
      have recent := (owned entry member).2
      omega)
  refine ⟨locals, ?_, owned⟩
  change (current.heap.replace _ _) = _
  rw [heap]
  simpa only [Heap.replace, List.map_append] using congrArg
    (· ++ before.heap.replace address.allocation
      { cell with cells := cell.cells.forget address.offset layout.bytes }) absent

grind_pattern StackFrame.store_local => StackFrame before current,
  store current (.pointer (.pointer write many child) address) value,
  (Except.ok after : Except Fault State)
grind_pattern StackFrame.store_caller => StackFrame before current,
  store current (.pointer (.pointer write many child) address) value,
  (Except.ok after : Except Fault State)

end Compiler.ZigAir.Memory
