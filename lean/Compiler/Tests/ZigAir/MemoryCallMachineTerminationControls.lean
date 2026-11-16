/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryCallMachineTermination
import Compiler.Tests.ZigAir.MemoryCallMachineLoopControls

namespace Compiler.Tests.ZigAir.MemoryCallMachineTerminationControls
open Compiler.ZigAir Compiler.ZigAir.Memory MemoryCallMachine
open MemoryCallMachineLoopControls

def caller : Function := ⟨[.scalar .bool], .scalar .bool,
  .bind 2 (.scalar .bool) (.memory (.argument 0)) <|
  .bind 9 (.scalar .bool) (.call 0 [.local 2]) <| .ret (.local 9)⟩

def program : Program := [select, caller, spinning]
def bounds (index : Nat) := (Finite.infer program)[index]?.join

theorem certified : Finite.Valid program bounds := by decide +kernel

/-- Branches, block exits, and calls terminate for arbitrary inputs and states.
The neighboring loop does not need a termination certificate. -/
theorem caller_terminates (args : List Value) (state : State) (resources : ResourcePolicy) :
    Terminates program (start program 1 args state resources) :=
  Finite.terminates certified 1 rfl args state resources

theorem loop_not_certified : bounds 2 = none := rfl

def recursive : Program := [⟨[], .scalar .unit,
  .bind 0 (.scalar .unit) (.call 0 []) (.ret (.constant (.scalar .unit)))⟩]

theorem recursion_not_inferred : Finite.infer recursive = [none] := rfl

/-- Supplying an arbitrary finite fuel bound cannot certify recursion. -/
theorem recursion_rejects_any_bound (steps : Nat) :
    ¬Finite.Valid recursive (fun _ => some steps) := by
  intro checked
  have impossible := checked ⟨0, by decide⟩
  simp [recursive, Finite.cost, Finite.primitiveCost] at impossible
  omega

def faulty : Program := [⟨[], .scalar .unit,
  .bind 0 (.scalar .unit) (.memory .unreachable) (.ret (.constant (.scalar .unit)))⟩]

/-- Termination includes ordinary faults; it does not imply memory safety. -/
theorem faulty_terminates (state : State) : Terminates faulty (start faulty 0 [] state) :=
  Finite.terminates (bounds := fun _ => some 2) (by decide +kernel) 0 rfl [] state

theorem faulty_reached : run faulty 1 0 [] {} =
    .finished (.error (.scalar .illegalBehavior)) {} := rfl

end Compiler.Tests.ZigAir.MemoryCallMachineTerminationControls
