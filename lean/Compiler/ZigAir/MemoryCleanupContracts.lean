/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryStackLaws

namespace Compiler.ZigAir.Memory

theorem cleanup_heap_eq_initial (before after : State) (valid : before.valid = true)
    (heap : after.heap = before.heap) : cleanup before.nextId after = after := by
  have initial := congrArg State.heap (cleanup_initial before valid)
  simp only [cleanup] at initial ⊢
  rw [heap, initial]
  rw [← heap]

theorem cleanup_idempotent (mark : Nat) (state : State) :
    cleanup mark (cleanup mark state) = cleanup mark state := by
  simp [cleanup, List.filter_filter]

end Compiler.ZigAir.Memory
