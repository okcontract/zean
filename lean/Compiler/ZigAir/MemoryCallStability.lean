/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryCall
import Compiler.ZigAir.MachineProofs

namespace Compiler.ZigAir.MemoryCall
open Memory

/-- Observing more transitions cannot change a completed invocation, including
its reached effects and cleanup. -/
theorem Program.finished_stable (program : Program true) (fuel extra : Nat)
    (args : List Value) (state after : State) (result : Except Fault Value)
    (done : program.runFuel fuel args state = .finished result after) :
    program.runFuel (fuel + extra) args state = .finished result after := by
  unfold Program.runFuel at done ⊢
  split at done
  · rename_i accepted
    rw [ite_eq_left accepted]
    simp only [Execution.resume] at done ⊢
    cases observed : Control.Machine.run semantics args fuel ⟨program.body, fun _ => none, state, []⟩ with
    | suspended config => simp only [observed] at done; contradiction
    | finished outcome =>
      rw [Control.Machine.finished_stable semantics args fuel extra _ _ observed]
      simpa only [observed] using done
  · rename_i rejected
    simpa only [ite_eq_right rejected] using done

end Compiler.ZigAir.MemoryCall
