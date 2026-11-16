/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.Verify.Lifetimes

namespace Compiler.Tests.ZigAir.MemoryOwnershipControls
open Compiler.ZigAir Compiler.ZigAir.Memory Ownership
deriving instance DecidableEq for Except

def byte : Ty := .scalar (.int false 8)
def owned : World :=
  ⟨⟨[(0, ⟨8, .array 2 byte, [(0, .scalar (.int false 8 42))], true, false⟩)], 1, 10⟩,
    [(0, 7)]⟩

example : owned.memory.valid = true := by decide +kernel
example : release owned 8 ⟨0, 0⟩ (.array 2 byte) = .error .memoryValidity := by decide +kernel
example : release owned 7 ⟨0, 1⟩ (.array 2 byte) = .error .memoryValidity := by decide +kernel
example : release owned 7 ⟨0, 0⟩ (.array 1 byte) = .error .memoryValidity := by decide +kernel

def retired : World := ⟨erase owned.memory 0, []⟩
example : release owned 7 ⟨0, 0⟩ (.array 2 byte) = .ok retired := by decide +kernel
example : release retired 7 ⟨0, 0⟩ (.array 2 byte) = .error .memoryValidity := by decide +kernel

/-- A new allocation may use the same physical base, but old pointers retain
their retired lifetime identity. -/
def reused : World :=
  (reserve retired 7 (.array 2 byte) (fun _ _ effects => (some 8, effects + 1)) (0 : Nat)).1.2
example : reused.memory.valid = true := by decide +kernel
example : reused.owners.owner 1 = some 7 := by decide +kernel
example : load reused.memory (.pointer (.pointer false false byte) ⟨0, 0⟩) =
    .error .unallocated := by decide +kernel
example : load reused.memory (.pointer (.pointer false false byte) ⟨1, 0⟩) =
    .error .uninitialized := by decide +kernel

/-- An allocator failure retains its private effects and the complete old
allocation, including the initialized byte a reallocating caller must retain. -/
example : reserve owned 7 (.array 4 byte) (fun _ _ effects => (none, effects + 1)) (0 : Nat) =
    ((.ok none, owned), 1) := by decide +kernel

def complete : World :=
  ⟨⟨[(0, ⟨8, .array 2 byte,
      [(0, .scalar (.int false 8 42)), (1, .scalar (.int false 8 43))], true, false⟩)], 1, 10⟩,
    [(0, 7)]⟩

def replacement := replaceBytes complete 7 ⟨0, 0⟩ 2 4
  (fun _ _ effects => (some 16, effects + 1)) (0 : Nat)
example : replacement.1.1 = .ok (some ⟨1, 0⟩) := by decide +kernel
example : replacement.2 = 1 := by decide +kernel
example : replacement.1.2.owners.owner 0 = none := by decide +kernel
example : replacement.1.2.owners.owner 1 = some 7 := by decide +kernel
example : load replacement.1.2.memory (.pointer (.pointer false false byte) ⟨1, 0⟩) =
    .ok (.scalar (.int false 8 42)) := by decide +kernel
example : load replacement.1.2.memory (.pointer (.pointer false false byte) ⟨1, 1⟩) =
    .ok (.scalar (.int false 8 43)) := by decide +kernel
example : load replacement.1.2.memory (.pointer (.pointer false false byte) ⟨1, 2⟩) =
    .error .uninitialized := by decide +kernel
example : load replacement.1.2.memory (.pointer (.pointer false false byte) ⟨0, 0⟩) =
    .error .unallocated := by decide +kernel
example : replaceBytes complete 7 ⟨0, 0⟩ 2 4 (fun _ _ effects => (none, effects + 1)) (0 : Nat) =
    ((.ok none, complete), 1) := by decide +kernel

/-- A corrupt allocator response overlapping the old live allocation rejects
and retains the external effect. It does not publish an owner or free the old one. -/
example : replaceBytes complete 7 ⟨0, 0⟩ 2 4 (fun _ _ effects => (some 8, effects + 1)) (0 : Nat) =
    ((.error .memoryValidity, complete), 1) := by decide +kernel

end Compiler.Tests.ZigAir.MemoryOwnershipControls
