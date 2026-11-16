/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.Tests.ZigAir.MemoryByteCopyControls
import Compiler.Tests.ZigAir.MemoryByteRangeTests
import Compiler.ZigAir.MemoryByteRangeRefinement
import Compiler.ZigAir.MemoryByteCopyFrame

namespace Compiler.Tests.ZigAir.MemoryUndefinedTransportAudit
open Compiler.ZigAir.Memory

/-- Transport cannot justify a concrete value for an undefined destination. -/
example : True := by
  fail_if_success
    have invented : load ByteCopyControls.copiedPrefix (.pointer (.pointer false false ByteArray.byte) ⟨1, 2⟩) =
        .ok (ByteArray.number 0) := by rfl
  trivial

end Compiler.Tests.ZigAir.MemoryUndefinedTransportAudit
