/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryCallMachineProofs
import Compiler.ZigAir.MemoryTypeEquality

/-! Synthetic call-stack controls. Expected outcomes are independent of the
program constructors; none of these controls claims native capture evidence. -/
namespace Compiler.Tests.ZigAir.MemoryCallMachineControls
open Compiler.ZigAir Compiler.ZigAir.Memory MemoryCallMachine

def byte : Ty := .scalar (.int false 8)
def ptr : Ty := .pointer true false byte
def unitRef : MemoryAir.Ref := .constant (.scalar .unit)

def initial : State := ⟨[(0, ⟨8, byte, [(0, .scalar (.int false 8 2))], true, false⟩)], 1, 9⟩
def args : List Value := [.pointer ptr ⟨0, 0⟩]

def caller : Function := ⟨[ptr], .scalar .unit,
  .bind 0 ptr (.memory (.argument 0))
  (.bind 1 ptr (.memory (.alloc byte))
  (.bind 2 (.scalar .unit) (.call 1 [.local 0]) (.ret unitRef)))⟩

def helper (tail : Code) : Function := ⟨[ptr], .scalar .unit,
  .bind 0 ptr (.memory (.argument 0))
  (.bind 1 ptr (.memory (.alloc byte))
  (.bind 2 (.scalar .unit) (.memory (.store (.local 0) (.constant (.scalar (.int false 8 9))))) tail))⟩

def success : Program := [caller, helper (.ret unitRef)]
def failure : Program := [caller, helper (.bind 3 (.scalar .unit) (.memory .unreachable) (.ret unitRef))]
def spinning : Program := [caller, helper (.loop rfl 4 (.repeat rfl 4))]

theorem return_cleans_only_private_storage :
    (match run success 20 0 args initial with
    | .finished (.ok (.scalar .unit)) after =>
      decide (after.heap.length = 1 ∧ after.nextId = 3) &&
        (match load after (.pointer ptr ⟨0, 0⟩) with
        | .ok (.scalar (.int false 8 value)) => decide (value = 9)
        | _ => false)
    | _ => false) = true := by decide +kernel

theorem fault_unwinds_and_keeps_caller_effects :
    (match run failure 20 0 args initial with
    | .finished (.error (.scalar .illegalBehavior)) after =>
      decide (after.heap.length = 1 ∧ after.nextId = 3) &&
        (match load after (.pointer ptr ⟨0, 0⟩) with
        | .ok (.scalar (.int false 8 value)) => decide (value = 9)
        | _ => false)
    | _ => false) = true := by decide +kernel

theorem suspension_retains_callee_and_continuation :
    (match run spinning 30 0 args initial with
    | .suspended config => decide (config.callers.length = 1 ∧
        config.active.mark = 2 ∧ config.active.control.state.heap.length = 3 ∧
        config.active.control.state.nextId = 3)
    | _ => false) = true := by decide +kernel

theorem resuming_does_not_restart (first second : Nat) :
    advance spinning second (run spinning first 0 args initial) =
      run spinning (first + second) 0 args initial :=
  (advance_add spinning first second (start spinning 0 args initial)).symm

def missing : Program := [⟨[], .scalar .unit,
  .bind 0 (.scalar .unit) (.call 99 []) (.ret unitRef)⟩]

theorem unknown_callee_rejects : run missing 1 0 [] {} = .finished (.error .unsupported) {} := rfl

def dangling : Program := [
  ⟨[], byte, .bind 0 ptr (.call 1 []) (.bind 1 byte (.memory (.load (.local 0))) (.ret (.local 1)))⟩,
  ⟨[], ptr, .bind 0 ptr (.memory (.alloc byte)) (.ret (.local 0))⟩]

theorem dangling_return_fault :
    run dangling 4 0 [] {} = .finished (.error .unallocated) ⟨[], 1, 9⟩ := rfl

theorem dangling_return_unsafe : ¬Safe dangling (start dangling 0 [] {}) :=
  unsafe_of_witness dangling _ 4 .unallocated ⟨[], 1, 9⟩ dangling_return_fault (by decide)

theorem reuse_does_not_revive_dangling_return :
    run dangling 4 0 [] {} .reuse = .finished (.error .unallocated) ⟨[], 1, 8⟩ := rfl

theorem reuse_preserves_caller_and_reclaims_storage :
    (match run success 20 0 args initial .reuse with
    | .finished (.ok (.scalar .unit)) after =>
      decide (after.heap.length = 1 ∧ after.nextId = 3 ∧ after.nextAddress = 9) &&
        (match load after (.pointer ptr ⟨0, 0⟩) with
        | .ok (.scalar (.int false 8 value)) => decide (value = 9)
        | _ => false)
    | _ => false) = true := by decide +kernel

def twice : Program := [
  ⟨[], .scalar .unit, .bind 0 (.scalar .unit) (.call 1 [])
    (.bind 1 (.scalar .unit) (.call 1 []) (.ret unitRef))⟩,
  ⟨[], .scalar .unit, .bind 0 ptr (.memory (.alloc byte)) (.ret unitRef)⟩]

/-- History accounting can exhaust before a later call even though no object
remains live. This is why model safety alone is not resource adequacy. -/
theorem history_can_exhaust_early :
    (match run twice 20 0 [] ⟨[], 0, addressLimit - 2⟩ with
    | .finished (.error .outOfMemory) after => decide (after.nextId = 1)
    | _ => false) = true := by decide +kernel

theorem reuse_completes_the_second_call :
    run twice 20 0 [] ⟨[], 0, addressLimit - 2⟩ .reuse =
      .finished (.ok (.scalar .unit)) ⟨[], 2, 8⟩ := rfl

end Compiler.Tests.ZigAir.MemoryCallMachineControls
