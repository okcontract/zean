/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryFrameVerification
import Compiler.ZigAir.MemoryVerificationFacts

namespace Compiler.ZigAir.Memory

/-- Initializing a fresh local preserves every pre-existing allocation. This
summary derives freshness from allocation, instead of asking each client to
relate the interpreter's successive allocation counters. -/
theorem StackFrame.initialized_local (valid : before.valid = true)
    (allocated : AllocationStep before owner pointer middle)
    (stored : StoreStep middle pointer value after) : StackFrame before after := by
  have frame := (StackFrame.refl before valid).allocate owner pointer middle allocated.equation
  have pointerEq := (allocate_pointer before owner pointer middle allocated.equation).1
  subst pointer
  exact frame.store_local true false owner ⟨before.nextId, 0⟩ value after (Nat.le_refl _) stored.equation

theorem LoadStep.stack (loaded : LoadStep before (.pointer (.pointer write many child) address) value)
    (frame : StackFrame before after) :
    LoadStep after (.pointer (.pointer write many child) address) value :=
  ⟨frame.old_load write many child address value loaded.equation⟩

grind_pattern StackFrame.initialized_local => AllocationStep before owner pointer middle,
  StoreStep middle pointer value after
grind_pattern LoadStep.stack => LoadStep before (.pointer (.pointer write many child) address) value,
  StackFrame before after

end Compiler.ZigAir.Memory
