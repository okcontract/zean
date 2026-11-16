/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryRootCapability
import Compiler.ZigAir.MemoryAllocationShape

namespace Compiler.ZigAir.Memory

theorem RootWritable.retained (cap : RootWritable before type objectId)
    (shape : before.heap.RetainsShape after.heap) : RootWritable after type objectId := by
  obtain ⟨cell, found, typed, writable⟩ := cap
  obtain ⟨updated, lookup, same⟩ := shape objectId cell found
  exact ⟨updated, lookup, same.2.1.trans typed, same.2.2.1.trans writable⟩

grind_pattern RootWritable.retained => RootWritable before type objectId,
  before.heap.RetainsShape after.heap

end Compiler.ZigAir.Memory
