/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.Tutorial.Buffer.Spec
import Compiler.ZigAir.MemoryWordFrameVerification

/-! Consequences of the buffer contract. These contain no program instructions
or register identities: they connect generic memory frames to the desired API. -/
namespace Compiler.Tutorial.Buffer.Spec
open Compiler.ZigAir Compiler.ZigAir.Memory Memory.WordArray

theorem exhausted (state after : State) (view : View) (index : Nat) (value : BitVec 32)
    (frame : StackFrame state after) (cap : Writable state view) :
    SafeResult state view index value (.error .outOfMemory) (cleanup state.nextId after) :=
  ⟨frame.cleanup_valid, writable_heap_eq state _ view frame.cleanup_heap cap,
    (HeapFrame.refl view state).heap_eq frame.cleanup_heap, .exhausted _ frame.cleanup_heap⟩

theorem rejected (state after : State) (view : View) (index : Nat) (value : BitVec 32)
    (frame : StackFrame state after) (cap : Writable state view) (outside : view.length ≤ index) :
    SafeResult state view index value (.ok (.scalar (.bool false))) (cleanup state.nextId after) :=
  ⟨frame.cleanup_valid, writable_heap_eq state _ view frame.cleanup_heap cap,
    (HeapFrame.refl view state).heap_eq frame.cleanup_heap, .rejected _ outside frame.cleanup_heap⟩

theorem replaced (state direct after : State) (view : View) (index : Nat) (value : BitVec 32)
    (cap : Writable state view) (inside : index < view.length)
    (stored : store state (view.pointer index) (number value) = .ok direct)
    (frame : StackFrame direct after) :
    SafeResult state view index value (.ok (.scalar (.bool true))) (cleanup state.nextId after) := by
  have counters := store_keeps_counters state _ _ direct stored
  have heap : (cleanup state.nextId after).heap = direct.heap := by
    rw [← counters.1]
    exact frame.cleanup_heap
  exact ⟨cleanup_preserves_valid _ _ frame.valid,
    writable_heap_eq direct _ view heap (writable_store state direct view _ _ stored cap),
    (frame_store state direct view index value inside stored).heapFrame.heap_eq heap,
    .replaced _ direct inside stored heap⟩

end Compiler.Tutorial.Buffer.Spec
