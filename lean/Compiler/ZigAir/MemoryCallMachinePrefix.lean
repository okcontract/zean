/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.ControlProjection
import Compiler.ZigAir.MemoryAirLaws
import Compiler.ZigAir.MemoryCallMachineEmbedding

namespace Compiler.ZigAir.MemoryCallMachine
open Memory

/-- Select straight-line memory bindings from an actual call-machine body.
The caller supplies a finite continuation for proving the prefix's effects. -/
def projectMemoryPrefix : Nat → Code → MemoryAir.Code → Option MemoryAir.Code
  | 0, _, tail => some tail
  | count + 1, .bind id type (.memory operation) next, tail =>
    (projectMemoryPrefix count next tail).map (.bind id type operation)
  | _, _, _ => none

theorem projectMemoryPrefix_sound (count : Nat) (code : Code) (tail result : MemoryAir.Code)
    (found : projectMemoryPrefix count code tail = some result) :
    count ≤ code.leadingBindings ∧
      code.prefixBindings count (embedCode tail.enableLoops) = embedCode result.enableLoops := by
  induction count generalizing code result with
  | zero =>
    cases found
    exact ⟨Nat.zero_le _, rfl⟩
  | succ count ih =>
    cases code <;> try contradiction
    case bind id type operation next =>
      cases operation <;> try contradiction
      case memory operation =>
        cases selected : projectMemoryPrefix count next tail with
        | none => simp [projectMemoryPrefix, selected] at found
        | some body =>
          have same : (.bind id type operation body : MemoryAir.Code) = result := by
            simpa [projectMemoryPrefix, selected] using found
          subst result
          obtain ⟨enough, reembed⟩ := ih next body selected
          exact ⟨Nat.succ_le_succ enough, by
            simp only [Control.Code.prefixBindings, Control.Code.enableLoops, embedCode, reembed]⟩

/-- Replay the checked effects of a straight-line memory fragment in the
interprocedural machine. The synthetic jump supplies the resulting environment
and state. The real activation stops at its original continuation before
executing the next instruction, with the same control and caller stacks. -/
theorem advance_memory_prefix (program : Program) (config : Config) (count : Nat)
    (projected : MemoryAir.Code) (enough : count ≤ config.active.control.code.leadingBindings)
    (capture : config.active.control.code.prefixBindings count (.jump tag exit) =
      embedCode projected.enableLoops)
    (ran : projected.eval MemoryAir.semantics config.active.arguments config.active.control.env
        config.active.control.state = .jumped tag value env after) :
    advance program count (.suspended config) =
      .suspended { config with active := { config.active with control :=
        { config.active.control with
          code := config.active.control.code.dropBindings count, env := env, state := after } } } := by
  induction count generalizing config projected with
  | zero =>
    cases projected <;> first | contradiction | cases capture
    simp only [MemoryAir.Code.eval_jump] at ran
    split at ran <;> cases ran
    rfl
  | succ count ih =>
    cases atCode : config.active.control.code <;>
      try (simp [atCode, Control.Code.leadingBindings] at enough; done)
    case bind id type operation next =>
      cases projected <;> simp only [atCode, Control.Code.prefixBindings, Control.Code.enableLoops, embedCode] at capture
      all_goals try contradiction
      all_goals try (cases capture; done)
      case bind pid ptype prim rest =>
        injection capture with idEq tyEq opEq tailEq
        subst pid ptype operation
        have countOK : count ≤ next.leadingBindings := by
          simpa only [atCode, Control.Code.leadingBindings, Nat.add_le_add_iff_right] using enough
        simp only [MemoryAir.Code.eval_bind] at ran
        cases eval : prim.eval config.active.arguments config.active.control.env config.active.control.state with
        | mk result current =>
          cases result with
          | error _ =>
            simp only [eval] at ran
            contradiction
          | ok item =>
            simp only [eval] at ran
            by_cases typed : item.hasType type = true
            · simp only [typed, ↓reduceIte] at ran
              let resumed : Config := { config with active := { config.active with control :=
                { config.active.control with
                  code := next, env := config.active.control.env.set id item,
                  state := current } } }
              have transitioned : step program config = .suspended resumed := by
                cases config with
                | mk active callers resources =>
                  cases active with
                  | mk returnType mark arguments control =>
                    cases control
                    simp only at atCode
                    subst_vars
                    simp only [step, Control.Machine.step, localSemantics, MemoryAir.semantics, eval, typed,
                      ↓reduceIte, resumed]
              simp only [advance, transitioned, Control.Code.dropBindings]
              exact ih resumed rest countOK tailEq ran
            · simp [typed] at ran

/-- Replay a prefix selected directly from the suspended function's code. -/
theorem advance_projected_prefix (program : Program) (config : Config) (count : Nat)
    (projected : MemoryAir.Code)
    (capture : projectMemoryPrefix count config.active.control.code (.jump tag exit) = some projected)
    (ran : projected.eval MemoryAir.semantics config.active.arguments config.active.control.env
        config.active.control.state = .jumped tag value env after) :
    advance program count (.suspended config) =
      .suspended { config with active := { config.active with control :=
        { config.active.control with
          code := config.active.control.code.dropBindings count, env := env, state := after } } } := by
  obtain ⟨enough, exactCode⟩ := projectMemoryPrefix_sound _ _ _ _ capture
  exact advance_memory_prefix program config count projected enough exactCode ran

end Compiler.ZigAir.MemoryCallMachine
