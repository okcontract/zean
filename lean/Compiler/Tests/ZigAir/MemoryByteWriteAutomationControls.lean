/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryByteWriteAutomation

namespace Compiler.Tests.ZigAir.MemoryByteWriteAutomationControls
open Compiler.ZigAir Compiler.ZigAir.Memory MemoryAir.Verify Memory.ByteArray

example (before after : State) (view : View) (contents : Nat → BitVec 8) (index : Nat)
    (represented : Represents before view contents)
    (stored : store before (view.pointer true false index) (number 32) = .ok after) :
    ∃ current, Represents after view current := by
  air_byte_writes
  air_witnesses

/-- Captured AIR spells out the pointer constructor, rather than retaining a
view helper application. Infer the view from its contract before matching it. -/
example (before after : State) (view : View) (contents : Nat → BitVec 8) (index : Nat)
    (represented : Represents before view contents)
    (stored : store before (.pointer (.pointer true false (.scalar (.int false 8)))
      ⟨view.address.allocation, view.address.offset + index⟩) (.scalar (.int false 8 32)) = .ok after) :
    ∃ current, Represents after view current := by
  air_byte_writes
  air_witnesses

example (state : State) (view : View) (contents : Nat → BitVec 8) (index : Nat) (pointer result : Value)
    (valid : state.valid = true) (region : Region state view true)
    (represented : Represents state view contents) (inside : index < view.length)
    (selected : sliceElementPointer state (view.slice true) index = .ok pointer)
    (loaded : load state pointer = .ok result) : result = number (contents index) := by
  simp only [View.slice] at selected
  air_byte_writes
  air_byte_reduce
  air_byte_writes
  air_byte_reduce

example (before after : State) (target source : View) (contents : Nat → BitVec 8) (count : Nat)
    (copied : CopyPost before after target source contents count) (inside : count ≤ target.length) :
    Region after ⟨target.address, count⟩ true ∧ ∃ current, Represents after ⟨target.address, count⟩ current := by
  air_byte_writes
  air_witnesses
  assumption

end Compiler.Tests.ZigAir.MemoryByteWriteAutomationControls

open Compiler.ZigAir Compiler.ZigAir.Memory MemoryAir.Verify Memory.ByteArray in
example (before after : State) (target source : View) (contents : Nat → BitVec 8) (count id : Nat)
    (cap : RootWritable before (.slice true byte) id)
    (copied : CopyPost before after target source contents count)
    (apart : id ≠ target.address.allocation) : RootWritable after (.slice true byte) id := by
  air_byte_writes
  assumption
