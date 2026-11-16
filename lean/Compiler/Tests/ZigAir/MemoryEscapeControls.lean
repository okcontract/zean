/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryEscape

namespace Compiler.Tests.ZigAir.MemoryEscapeControls
open Compiler.ZigAir Compiler.ZigAir.Memory

def byte : Ty := .scalar (.int false 8)
def escaped : State :=
  ⟨[(0, ⟨8, .pointer false false byte,
      [(0, .pointer (.pointer false false byte) ⟨1, 0⟩)], true, false⟩),
    (1, ⟨16, byte, [(0, .scalar (.int false 8 42))], true, true⟩)], 2, 17⟩

theorem valid : escaped.valid = true := by decide +kernel

/-- The directly returned object is persistent, but its stored pointer names a
callee local. Checking only the direct return value would miss this escape. -/
theorem indirect : Reachable escaped.heap [0] 1 :=
  .stored (parent := 0) (cell := ⟨8, .pointer false false byte,
      [(0, .pointer (.pointer false false byte) ⟨1, 0⟩)], true, false⟩)
    (offset := 0) (value := .pointer (.pointer false false byte) ⟨1, 0⟩)
    (.root (by simp)) rfl (by simp) (by simp [Value.lifetimes])

theorem rejected : ¬ EscapeSafe escaped 1 [0] := by
  intro safe
  obtain ⟨cell, found, retained⟩ := safe 1 indirect
  have same : cell = ⟨16, byte, [(0, .scalar (.int false 8 42))], true, true⟩ :=
    Option.some.inj found.symm
  subst cell
  simp at retained

example : (cleanup 1 escaped).heap.lookup 0 = escaped.heap.lookup 0 := rfl
example : (cleanup 1 escaped).heap.lookup 1 = none := rfl

end Compiler.Tests.ZigAir.MemoryEscapeControls
