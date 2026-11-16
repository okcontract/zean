/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryResources
import Compiler.ZigAir.MemoryProofSearch

namespace Compiler.ZigAir.MemoryAir.Verify
open Memory

/-- Derive cursor costs and discharge slice-slot exhaustion from the caller's
explicit budget. The resulting facts are ordinary theorem applications. -/
elab "air_resources" : tactic => Lean.Elab.Tactic.liftMetaTactic fun goal =>
  saturateFacts goal #[``allocate_slice_cost, ``store_keeps_counters, ``allocate_slice_no_fault] 3

end Compiler.ZigAir.MemoryAir.Verify
