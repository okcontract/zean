/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryByteArrayGeometry

namespace Compiler.ZigAir.Memory.ByteArray
variable {write : Bool}

/-- Converting a fixed byte-array pointer to a many-pointer retains the address
and constness. No byte is read; a later read still requires initialization. -/
theorem Region.array_pointer (valid : state.valid = true) (cap : Region state view write)
    (mutable : Bool) (count : Nat) (address : Address) (same : view.address = address) :
    pointerCast state (.pointer mutable true byte)
      (.pointer (.pointer mutable false (.array count byte)) address) =
      .ok (.pointer (.pointer mutable true byte) address) := by
  subst address
  obtain ⟨cell, accessed⟩ := cap.range_access valid (Nat.zero_le _)
  cases mutable <;>
    simp only [pointerCast, pointerCompatible, byte, Ty.layout, Ty.leafLayout,
      Bool.false_and, Bool.true_and, Bool.not_false, Bool.not_true, Bool.false_eq_true,
      decide_true, Bool.or_true, Bool.or_false, ↓reduceIte, accessed, bind, Except.bind]

grind_pattern Region.array_pointer => Region state view write,
  pointerCast state (.pointer mutable true byte)
    (.pointer (.pointer mutable false (.array count byte)) address)

end Compiler.ZigAir.Memory.ByteArray
