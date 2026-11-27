/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryAir
import Compiler.ZigAir.MemoryRootCapability
import Lean.Elab.Tactic
import Lean.Meta.Reduce

/-! Checked bindings for client invariants. Selection inspects the generated
program and requires a proof that the requested entry exists. There is no
fallback register, source-name guess, or change to executed instructions.
Traversal includes both branches; an allocation's ordinal is not a claim about
its dynamic lifetime identity or whether execution reaches it. -/
namespace Compiler.ZigAir.MemoryAir.Bindings
open Memory

structure Binding where
  register : Nat
  type : Ty
  deriving DecidableEq, Repr

/-- Cache a selection's normal form while retaining a kernel-checked equality
to the selector. The witness cannot be omitted by the elaborator. -/
def checked {α : Type} (_selection value : α) (_witness : _selection = value) : α := value

/-- Evaluate only the binding selector during elaboration. Unlike an unchecked
evaluation tactic, this returns a term containing a reflexivity proof that the
computed result is definitionally equal to the original selection. -/
elab "air_binding% " selection:term : term => do
  let original ← Lean.Elab.Term.elabTerm selection none
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let original ← Lean.instantiateMVars original
  let value ← Lean.Meta.withTransparency .all (Lean.Meta.reduce original)
  Lean.Meta.mkAppM ``checked #[original, value, ← Lean.Meta.mkEqRefl value]

def primitives : Control.Code Ty P Ref loops → List (Binding × P)
  | .bind id ty prim next => (⟨id, ty⟩, prim) :: primitives next
  | .branch _ yes no => primitives yes ++ primitives no
  | .block _ _ body next => primitives body ++ primitives next
  | .loop _ _ body => primitives body
  | .jump .. | .ret .. | .repeat .. => []

def arguments (code : Control.Code Ty Prim Ref loops) : List Binding :=
  (primitives code).filterMap fun (binding, prim) => match prim with
    | .argument _ => some binding
    | _ => none

def allocations (code : Control.Code Ty Prim Ref loops) : List Binding :=
  (primitives code).filterMap fun (binding, prim) => match prim with
    | .alloc _ => some binding
    | _ => none

def casts (code : Control.Code Ty Prim Ref loops) : List Binding :=
  (primitives code).filterMap fun (binding, prim) => match prim with
    | .pointerCast .. => some binding
    | _ => none

/-- Semantic selectors fail on ambiguity instead of choosing the first match.
Compiler-local renumbering and unrelated insertions do not change the key. -/
def unique : List α → Option α
  | [value] => some value
  | _ => none

theorem unique_exact (values : List α) (selected : unique values = some value) : values = [value] := by
  cases values with
  | nil => cases selected
  | cons head tail =>
    cases tail with
    | nil => cases selected; rfl
    | cons => cases selected

/-- Select the unique result of a typed operation, including its operands and
arithmetic mode. Chaining selections follows dataflow across local renumbering. -/
def resultOf (code : Control.Code Ty Prim Ref loops) (type : Ty) (operation : Prim) : Option Binding :=
  unique ((primitives code).filterMap fun (binding, prim) =>
    if binding.type = type ∧ prim = operation then some binding else none)

def argument (code : Control.Code Ty Prim Ref loops) (index : Nat) : Option Binding :=
  unique ((primitives code).filterMap fun (binding, prim) => match prim with
    | .argument actual => if actual = index then some binding else none
    | _ => none)

def allocationOfType (code : Control.Code Ty Prim Ref loops) (type : Ty) : Option Binding :=
  unique ((primitives code).filterMap fun (binding, prim) => match prim with
    | .alloc actual => if actual = type then some binding else none
    | _ => none)

def castToType (code : Control.Code Ty Prim Ref loops) (type : Ty) : Option Binding :=
  unique ((primitives code).filterMap fun (binding, prim) => match prim with
    | .pointerCast actual _ => if actual = type then some binding else none
    | _ => none)

def loops : Control.Code Ty P Ref enabled → List Nat
  | .loop _ id body => id :: loops body
  | .bind _ _ _ next => loops next
  | .branch _ yes no => loops yes ++ loops no
  | .block _ _ body next => loops body ++ loops next
  | .jump .. | .ret .. | .repeat .. => []

/-- A compiler local containing a saved value. Mutable locals additionally
carry the capability needed by a later store. The lifetime ID is supplied by
an execution invariant, never inferred from a static allocation ordinal. -/
def Binding.Saved (binding : Binding) (id : Nat) (env : Env) (state : State) (value : Value) : Prop :=
  match binding.type with
  | .pointer writable false child =>
    let pointer := Value.pointer binding.type ⟨id, 0⟩
    env binding.register = some pointer ∧ load state pointer = .ok value ∧
      (writable = true → RootWritable state child id)
  | _ => False

/-- The stored value is unchanged when only other allocations change. -/
theorem Binding.Saved.heap_eq (binding : Binding) (id : Nat) (env : Env) (before after : State)
    (value : Value) (same : after.heap = before.heap) (saved : binding.Saved id env before value) :
    binding.Saved id env after value := by
  rcases binding with ⟨register, ty⟩
  cases ty <;> simp only [Binding.Saved] at saved ⊢
  all_goals try contradiction
  next writable many child =>
    cases many <;> simp only at saved ⊢
    simpa only [load, access, RootWritable, same] using saved

end Compiler.ZigAir.MemoryAir.Bindings
