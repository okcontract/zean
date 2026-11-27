/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryCallMachineProofs

/-! Invocation contexts for the explicit call-stack machine. A caller can
reason about a callee in isolation, then attach its actual continuation.
Suspension retains the callee; it never supplies a return value to the caller.
Both resource policies use the same laws. -/
namespace Compiler.ZigAir.MemoryCallMachine
open Memory

/-- Attach saved caller frames to an isolated invocation. Completed faults
unwind the callers; completed values pass through the caller's result-type check.
No extra cleanup is applied to the already completed callee. -/
def attach (resources : ResourcePolicy) (callers : List Caller) : Execution → Execution
  | .finished (.error fault) state => unwind fault state callers resources
  | .finished (.ok value) state =>
    match callers with
    | [] => .finished (.ok value) state
    | caller :: rest =>
      if value.hasType caller.resultType then
        .suspended ⟨{ caller.activation with control :=
          { caller.activation.control with state := state, env := caller.activation.control.env.set caller.resultId value } }, rest, resources⟩
      else unwind .malformed (resources.cleanup caller.activation.mark state) rest resources
  | .suspended config => .suspended { config with callers := config.callers ++ callers }

def Uses (resources : ResourcePolicy) : Execution → Prop
  | .finished .. => True
  | .suspended config => config.resources = resources

theorem unwind_append (fault : Fault) (state : State) (inner outer : List Caller)
    (resources : ResourcePolicy) :
    unwind fault state (inner ++ outer) resources =
      attach resources outer (unwind fault state inner resources) := by
  induction inner generalizing state with
  | nil => rfl
  | cons caller rest ih => exact ih _

theorem unwind_finished (program : Program) (fuel : Nat) (resources : ResourcePolicy)
    (fault : Fault) (state : State) (callers : List Caller) :
    advance program fuel (unwind fault state callers resources) = unwind fault state callers resources := by
  induction callers generalizing state with
  | nil => exact advance_finished _ _ _ _
  | cons caller rest ih => exact ih _

theorem fail_attach (config : Config) (fault : Fault) (state : State) (outer : List Caller) :
    fail { config with callers := config.callers ++ outer } fault state =
      attach config.resources outer (fail config fault state) :=
  unwind_append fault _ config.callers outer config.resources

theorem returned_attach (config : Config) (value : Value) (state : State) (outer : List Caller) :
    returned { config with callers := config.callers ++ outer } value state =
      attach config.resources outer (returned config value state) := by
  simp only [returned]
  split
  · exact unwind_append _ _ _ _ _
  · cases config.callers with
    | nil => rfl
    | cons caller rest =>
      simp only [List.cons_append]
      split
      · rfl
      · exact unwind_append _ _ _ _ _

/-- Adding callers leaves each active transition unchanged. In particular,
local control frames and arguments belong to the callee until it returns. -/
theorem step_attach (program : Program) (config : Config) (outer : List Caller) :
    step program { config with callers := config.callers ++ outer } =
      attach config.resources outer (step program config) := by
  cases body : config.active.control.code with
  | bind id ty operation next =>
    cases operation <;> simp only [step, body]
    all_goals repeat' (split <;> try simp_all only [])
    all_goals first | exact fail_attach config _ _ outer | exact returned_attach config _ _ outer | rfl
  | _ =>
    simp only [step, body]
    repeat' (split <;> try simp_all only [])
    all_goals first | exact fail_attach config _ _ outer | exact returned_attach config _ _ outer | rfl

theorem uses_unwind (resources : ResourcePolicy) (fault : Fault) (state : State) (callers : List Caller) :
    Uses resources (unwind fault state callers resources) := by
  induction callers generalizing state with
  | nil => trivial
  | cons caller rest ih => exact ih _

theorem uses_fail (config : Config) (fault : Fault) (state : State) :
    Uses config.resources (fail config fault state) := uses_unwind _ _ _ _

theorem uses_returned (config : Config) (value : Value) (state : State) :
    Uses config.resources (returned config value state) := by
  simp only [returned]
  split
  · exact uses_unwind _ _ _ _
  · cases callers : config.callers with
    | nil => trivial
    | cons caller rest =>
      simp only []
      split
      · rfl
      · exact uses_unwind _ _ _ _

theorem uses_step (program : Program) (config : Config) : Uses config.resources (step program config) := by
  cases body : config.active.control.code with
  | bind id ty operation next =>
    cases operation <;> simp only [step, body]
    all_goals repeat' (split <;> try simp_all only [])
    all_goals first | exact uses_fail config _ _ | exact uses_returned config _ _ | rfl
  | _ =>
    simp only [step, body]
    repeat' (split <;> try simp_all only [])
    all_goals first | exact uses_fail config _ _ | exact uses_returned config _ _ | rfl

theorem uses_start (program : Program) (root : Nat) (args : List Value) (state : State)
    (resources : ResourcePolicy) : Uses resources (start program root args state resources) := by
  simp only [start]
  split
  · trivial
  · split; rfl; trivial

/-- The actual call instruction is an isolated invocation with its caller
attached. Missing functions, argument rejection and result-type checks remain
part of execution rather than being assumed away by a procedure summary. -/
theorem step_call (program : Program) (config : Config) (id : Nat) (type : Ty)
    (target : Nat) (references : List MemoryAir.Ref) (next : Code)
    (atCall : config.active.control.code = .bind id type (.call target references) next) :
    step program config =
      match references.mapM (fun ref => ref.eval config.active.control.env) with
      | .error fault => fail config fault config.active.control.state
      | .ok args => attach config.resources
          (⟨{ config.active with control := { config.active.control with code := next } }, id, type⟩ :: config.callers)
          (start program target args config.active.control.state config.resources) := by
  simp only [step, atCall, start]
  repeat' (split <;> try simp_all only [])
  all_goals rfl

/-- Attach caller frames to a known finite execution. Reachability stops
at the corresponding continuation, even if the isolated run used extra
fuel after returning. -/
theorem Steps.attach (reached : Steps program first last) (consistent : Uses policy first)
    (outer : List Caller) :
    Steps program (MemoryCallMachine.attach policy outer first) (MemoryCallMachine.attach policy outer last) := by
  induction reached with
  | refl => exact .refl _
  | step config _ ih =>
    have same : config.resources = policy := consistent
    subst policy
    change Steps _ (.suspended { config with callers := config.callers ++ outer }) _
    apply Steps.step
    rw [step_attach]
    exact ih (uses_step _ _)

/-- Resume a real call instruction after a successful isolated execution of
its actual target. Both the argument resolution and result binding are checked. -/
theorem Steps.call_returned {register : Nat} (atCall : config.active.control.code = .bind register type (.call target refs) next)
    (resolved : refs.mapM (fun ref => ref.eval config.active.control.env) = .ok args)
    (reached : Steps program (start program target args config.active.control.state config.resources)
      (.finished (.ok value) after))
    (typed : value.hasType type = true) :
    Steps program (.suspended config)
      (.suspended { config with active := { config.active with control :=
        { config.active.control with
          code := next, env := config.active.control.env.set register value, state := after } } }) := by
  apply Steps.step
  rw [step_call _ _ _ _ _ _ _ atCall, resolved]
  have attached := reached.attach (uses_start program target args _ _)
    (⟨{ config.active with control := { config.active.control with code := next } }, register, type⟩ :: config.callers)
  simpa only [MemoryCallMachine.attach, typed, ↓reduceIte] using attached

end Compiler.ZigAir.MemoryCallMachine
