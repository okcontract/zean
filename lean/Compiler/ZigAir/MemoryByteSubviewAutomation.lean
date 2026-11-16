/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryByteSubviews
import Compiler.ZigAir.MemoryByteCopyAutomation

namespace Compiler.ZigAir.MemoryAir.Verify
open Memory

attribute [air_simps] ByteArray.View.at ByteArray.View.suffix

/-- Resolve checked byte subviews before using them to frame a copy. This
exposes addresses through proved region bounds, without unfolding the heap. -/
elab "air_byte_subviews" : tactic => Lean.Elab.Tactic.liftMetaTactic fun goal =>
  saturateFacts goal #[``ByteArray.remaining_bound, ``ByteArray.Region.offset_selected, ``ByteArray.Region.offset_outcome,
    ``ByteArray.Region.slice_selected,
    ``ByteRange.result_valid, ``store_preserves_valid] 3

end Compiler.ZigAir.MemoryAir.Verify
