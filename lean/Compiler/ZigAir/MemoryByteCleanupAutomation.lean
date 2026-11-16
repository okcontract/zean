/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryByteWriteAutomation

namespace Compiler.ZigAir.MemoryAir.Verify

/-- Expose preservation of live byte views and initialized contents across
invocation cleanup. One pass avoids recursively inventing cleanup histories. -/
elab "air_byte_cleanup" : tactic => Lean.Elab.Tactic.liftMetaTactic fun goal =>
  saturateFacts goal #[``Memory.ByteArray.Region.cleanup, ``Memory.ByteArray.Represents.cleanup] 1

end Compiler.ZigAir.MemoryAir.Verify
