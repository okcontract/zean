/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryByteCopyWP

/-! Independent synthetic controls for bulk copies, including reached effects
on failure. These tests check the byte-copy model directly. -/
namespace Compiler.ZigAir.Memory.ByteCopyControls
open Compiler.ZigAir.Memory.ByteArray
set_option maxRecDepth 4096

def partialState : State :=
  ⟨[(0, ⟨1, .array 3 byte, [(0, number 41), (1, number 42)], false, false⟩),
    (1, ⟨4, .array 3 byte, [], true, false⟩)], 2, 7⟩
def source : Value := .pointer (.pointer false true byte) ⟨0, 0⟩
def target (count : Nat) : Value := .slice (.slice true byte) ⟨1, 0⟩ count
def copiedPrefix : State :=
  ⟨[(0, ⟨1, .array 3 byte, [(0, number 41), (1, number 42)], false, false⟩),
    (1, ⟨4, .array 3 byte, [(1, number 42), (0, number 41)], true, false⟩)], 2, 7⟩

example : partialState.valid = true := by rfl
example : ByteRange.copy partialState (target 2) source = (.ok (), copiedPrefix) := by rfl
example : ByteRange.copy partialState (target 3) source = (.ok (), copiedPrefix) := by rfl
example : (MemoryAir.Prim.copyBytes (.constant (target 3)) (.constant source)).eval [] (fun _ => none) partialState =
    (.ok (.scalar .unit), copiedPrefix) := by rfl
example : load copiedPrefix (.pointer (.pointer false false byte) ⟨1, 2⟩) = .error .uninitialized := rfl

/-- Undefined transport must erase a previously initialized destination. -/
def initializedDestination : State :=
  ⟨[(0, ⟨1, .array 3 byte, [(0, number 41), (1, number 42)], false, false⟩),
    (1, ⟨4, .array 3 byte, [(2, number 99)], true, false⟩)], 2, 7⟩
example : ByteRange.copy initializedDestination (target 3) source = (.ok (), copiedPrefix) := rfl
example : ByteRange.copy partialState (.slice (.slice true byte) ⟨0, 1⟩ 2) source =
    (.error .memoryValidity, partialState) := by rfl
example : ByteRange.copy partialState (.slice (.slice false byte) ⟨1, 0⟩ 2) source =
    (.error .readOnly, partialState) := by rfl
example : ByteRange.copy partialState (.slice (.slice true byte) ⟨1, 2⟩ 2) source =
    (.error .memoryValidity,
      ⟨[(0, ⟨1, .array 3 byte, [(0, number 41), (1, number 42)], false, false⟩),
        (1, ⟨4, .array 3 byte, [(2, number 41)], true, false⟩)], 2, 7⟩) := by rfl
example : ByteRange.copy partialState (target 0) source = (.ok (), partialState) := by rfl

private def moveInput : State :=
  ⟨[(0, ⟨8, .array 5 byte, [(0, number 1), (1, number 2), (2, number 3), (3, number 4),
    (4, number 5)], true, false⟩)], 1, 16⟩

private def observeMove (source target : Nat) : Except Fault Unit × Except Fault (List (BitVec 8)) :=
  let (result, after) := ByteRange.move moveInput (.slice (.slice true byte) ⟨0, target⟩ 4)
    (.pointer (.pointer false true byte) ⟨0, source⟩)
  (result, ByteRange.read after ⟨0, 0⟩ 5)

-- Both directions overlap, so a fixed traversal order would destroy a source byte.
example : observeMove 1 0 = (.ok (), .ok [2, 3, 4, 5, 5]) := by rfl
example : observeMove 0 1 = (.ok (), .ok [1, 1, 2, 3, 4]) := by rfl
example : observeMove 0 0 = (.ok (), .ok [1, 2, 3, 4, 5]) := by rfl

end Compiler.ZigAir.Memory.ByteCopyControls
