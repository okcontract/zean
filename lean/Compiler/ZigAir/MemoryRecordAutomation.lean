/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryRecordWP
import Compiler.ZigAir.MemoryProofSearch
import Compiler.ZigAir.MemoryRecordCapability
import Compiler.ZigAir.MemoryByteCopyFrame
import Compiler.ZigAir.MemoryRootShape

namespace Compiler.ZigAir.MemoryAir.Verify
open Memory

/-- Read observations do not depend on the pointer's write flag. This changes
the read view only; write permission still requires a writable capability. -/
theorem load_write_view (state : State) (many : Bool) (child : Ty) (address : Address) (value : Value)
    (loaded : LoadStep state (.pointer (.pointer false many child) address) value) :
    LoadStep state (.pointer (.pointer true many child) address) value := ⟨loaded.equation⟩

/-- Preserve checked field selections while a callee allocates and initializes
its own locals. Field layouts and caller initialization remain contract facts. -/
elab "air_record_prepare" : tactic => Lean.Elab.Tactic.liftMetaTactic fun goal =>
  saturateFacts goal #[``StackFrame.field_pointer, ``RootWritable.stack, ``load_write_view,
    ``LoadStep.copied_other, ``RootWritable.copied_other, ``field_pointer_copied_other,
    ``RootWritable.retained, ``ScalarField.store_no_fault] 3

end Compiler.ZigAir.MemoryAir.Verify
