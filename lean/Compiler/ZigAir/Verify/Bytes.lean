/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.Verify.Core
import Compiler.ZigAir.MemoryByteCopyAutomation
import Compiler.ZigAir.MemoryByteReadAutomation
import Compiler.ZigAir.MemoryByteFields
import Compiler.ZigAir.MemoryByteMoveContracts

/-! Optional initialized byte-region, copy, and move contracts, including declared
byte fields inside a complete record. -/

namespace Compiler.ZigAir.Memory.ByteArray

def View.window (v : View) (start count : Nat) : View := ⟨v.at start, count⟩

/-- Premises for a nonempty initialized copy between two slice windows.
The initialization and separation obligations apply only to the selected bytes. -/
structure CopyRanges (s : State) (dst src : View) (atDst atSrc count : Nat)
    (contents : Nat → BitVec 8) : Prop where
  writable : Region s dst true
  readable : Region s src false
  dstBound : atDst + count ≤ dst.length
  srcBound : atSrc + count ≤ src.length
  initialized : Represents s (src.window atSrc count) contents
  disjoint : Disjoint (src.window atSrc count) (dst.window atDst count)

/-- Split a source-level copy contract into named premises and discharge facts
already in scope. Missing premises retain their field names in the goal view. -/
macro "air_copy_ranges" : tactic => `(tactic|
  (apply CopyRanges.mk <;> first | assumption | omega | skip))

end Compiler.ZigAir.Memory.ByteArray
