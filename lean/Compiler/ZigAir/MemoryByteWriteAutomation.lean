/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryByteWriteContracts
import Compiler.ZigAir.MemoryByteReadAutomation

namespace Compiler.ZigAir.MemoryAir.Verify
open Memory

@[air_simps] theorem slice_value_valid (writable : Bool) (child : Ty)
    (address : Address) (length : Nat) :
    (Value.slice (.slice writable child) address length).valid = decide (length < addressLimit) := rfl

/-- A truncated extent has the same minimum before and after conversion from
AIR's signed representation. This also covers negative values conservatively. -/
@[air_simps] theorem min_toNat (left right : Int) :
    (min left right).toNat = min left.toNat right.toNat := by omega

/-- Infer initialized prefixes after a specified copy and preserve initialization
through byte replacement and unrelated local stores. -/
elab "air_byte_writes" : tactic => Lean.Elab.Tactic.liftMetaTactic fun goal =>
  saturateFacts goal #[``ByteArray.CopyPost.valid, ``ByteArray.CopyPost.prefix_region,
    ``ByteArray.CopyPost.prefix_read, ``ByteArray.LoadStep.copy_post_other, ``ByteArray.copy_post_root,
    ``ByteArray.Region.stored, ``ByteArray.Region.selected_mutable,
    ``ByteArray.Represents.loaded_mutable, ``ByteArray.Represents.written_int,
    ``ByteArray.Represents.stored_other, ``ByteArray.Region.write_int_no_fault,
    ``ByteArray.Region.older] 3

end Compiler.ZigAir.MemoryAir.Verify
