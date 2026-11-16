/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryFrameVerification
import Compiler.ZigAir.MemoryWordVerificationFacts
import Compiler.ZigAir.MemoryStackPrefix

/-! Word-view capabilities preserved by invocation stack frames. -/
namespace Compiler.ZigAir.Memory

theorem WordArray.writable_stack (frame : StackFrame before after) (view : WordArray.View)
    (cap : WordArray.Writable before view) : WordArray.Writable after view := by
  obtain ⟨extent, cell, found, typed, writable, bound⟩ := cap
  exact ⟨extent, cell, frame.old_lookup _ _ found, typed, writable, bound⟩

theorem WordArray.view_older (state : State) (view : WordArray.View) (valid : state.valid = true)
    (cap : WordArray.Writable state view) : view.allocation < state.nextId := by
  obtain ⟨_, cell, found, _⟩ := cap
  exact (valid_lookup state view.allocation cell valid found).1

end Compiler.ZigAir.Memory
