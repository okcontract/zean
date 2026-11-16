/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryOwnership
import Compiler.ZigAir.MemoryByteCopy

namespace Compiler.ZigAir.Memory.Ownership

/-- An explicit allocate/copy/release protocol. This is a reusable boundary
model, not a claim about Zig's allocator vtable or a native realloc function.
OOM preserves the old owner; a reached copy fault retains both allocations and
its completed prefix. A zero-size replacement retires the old allocation. -/
def replaceBytes (world : World) (allocator : Nat) (old : Address) (oldCount newCount : Nat)
    (allocate : RegionAllocation.Allocator σ) (effects : σ) :
    (Except Fault (Option Address) × World) × σ :=
  -- Validate the old owner before making the external allocation request.
  match release world allocator old (.array oldCount ByteRange.byte) with
  | .error fault => ((.error fault, world), effects)
  | .ok _ =>
    let ((allocation, reserved), reached) := reserve world allocator (.array newCount ByteRange.byte) allocate effects
    match allocation with
    | .error fault => ((.error fault, reserved), reached)
    | .ok none => ((.ok none, reserved), reached)
    | .ok (some fresh) =>
      let (copied, memory) := ByteRange.copy reserved.memory
        (.slice (.slice true ByteRange.byte) fresh (min oldCount newCount))
        (.pointer (.pointer false true ByteRange.byte) old)
      let updated := { reserved with memory }
      match copied with
      | .error fault => ((.error fault, updated), reached)
      | .ok () =>
        match release updated allocator old (.array oldCount ByteRange.byte) with
        | .error fault => ((.error fault, updated), reached)
        | .ok after => ((.ok (some fresh), after), reached)

theorem reserve_valid (world : World) (allocator : Nat) (type : Ty)
    (allocate : RegionAllocation.Allocator σ) (effects : σ) (valid : world.memory.valid = true) :
    (reserve world allocator type allocate effects).1.2.memory.valid = true :=
  RegionAllocation.reserve_preserves_valid world.memory type allocate effects valid

/-- Safety of the heap representation holds on every response, including
failed external allocation and partially completed copying. Fault freedom is a
separate caller obligation. -/
theorem replaceBytes_valid (world : World) (allocator : Nat) (old : Address) (oldCount newCount : Nat)
    (allocate : RegionAllocation.Allocator σ) (effects : σ) (valid : world.memory.valid = true) :
    (replaceBytes world allocator old oldCount newCount allocate effects).1.2.memory.valid = true := by
  unfold replaceBytes
  cases checked : release world allocator old (.array oldCount ByteRange.byte) with
  | error fault => exact valid
  | ok discarded =>
    generalize response : reserve world allocator (.array newCount ByteRange.byte) allocate effects = allocated
    obtain ⟨⟨allocation, reserved⟩, reached⟩ := allocated
    have reservedValid := reserve_valid world allocator (.array newCount ByteRange.byte) allocate effects valid
    rw [response] at reservedValid
    cases allocation with
    | error fault => exact reservedValid
    | ok address =>
      cases address with
      | none => exact reservedValid
      | some fresh =>
        dsimp only
        generalize ran : ByteRange.copy reserved.memory
          (.slice (.slice true ByteRange.byte) fresh (min oldCount newCount))
          (.pointer (.pointer false true ByteRange.byte) old) = copied
        obtain ⟨result, memory⟩ := copied
        have memoryValid := ByteRange.copy_valid reserved.memory
          (.slice (.slice true ByteRange.byte) fresh (min oldCount newCount))
          (.pointer (.pointer false true ByteRange.byte) old) reservedValid
        rw [ran] at memoryValid
        cases result with
        | error fault => exact memoryValid
        | ok result =>
          cases result
          dsimp only
          cases released : release { reserved with memory } allocator old (.array oldCount ByteRange.byte) with
          | error fault => exact memoryValid
          | ok after => exact release_valid released

end Compiler.ZigAir.Memory.Ownership
