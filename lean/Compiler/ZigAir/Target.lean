/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
/-! The memory model has one admitted ABI. Adding another target requires a
layout interpretation and new admission evidence; changing these constants is
not sufficient. Scalar-only captures have a separate admission boundary. -/
namespace Compiler.ZigAir.Target

abbrev pointerBits : Nat := 64
abbrev pointerBytes : Nat := 8
abbrev pointerAlignment : Nat := 8

def acceptsMemory (arch os : String) (bits : Nat) (endianness : String) : Bool :=
  arch == "aarch64" && os == "macos" && bits == pointerBits && endianness == "little"

theorem accepted_geometry (arch os : String) (bits : Nat) (endianness : String)
    (accepted : acceptsMemory arch os bits endianness = true) :
    arch = "aarch64" ∧ os = "macos" ∧ bits = 64 ∧ endianness = "little" := by
  simpa [acceptsMemory, pointerBits, and_assoc] using accepted

theorem pointer_word : 8 * pointerBytes = pointerBits := rfl

end Compiler.ZigAir.Target
