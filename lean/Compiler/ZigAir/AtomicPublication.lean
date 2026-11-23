/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
namespace Compiler.ZigAir.AtomicPublication

/-! One writer fills two initially uninitialized slots, then sets a flag.
The slots and flag occupy three distinct live bytes. Only the writer changes
them. A reader may see the flag's initial zero or the one the writer stored.

To model release/acquire for this example, the release store saves a snapshot
of the table writes so far. An acquire load that sees that store gets the
snapshot. Reading a slot that the snapshot doesn't cover gives
`.unprotectedRead`. -/

inductive Slot where | first | second deriving DecidableEq, Repr
inductive StoreOrder where | monotonic | release deriving DecidableEq, Repr
inductive LoadOrder where | monotonic | acquire deriving DecidableEq, Repr

inductive Write where
  | entry (destination input : Slot)
  | ready (order : StoreOrder)
  deriving DecidableEq, Repr

structure Protocol where
  writer : List Write
  reader : LoadOrder
  deriving DecidableEq, Repr

def publication : Protocol :=
  ⟨[.entry .first .first, .entry .second .second, .ready .release], .acquire⟩

abbrev View := Slot → Option UInt8

structure State where
  localWrites : View
  /-- Outer `none` means the flag store has not executed. -/
  published : Option View

def initial : State := ⟨fun _ => none, none⟩

def write (inputs : Slot → UInt8) (s : State) : Write → State
  | .entry dst src =>
    let writes i := if i = dst then some (inputs src) else s.localWrites i
    { s with localWrites := writes }
  | .ready order =>
    let view : View := match order with
      | .release => s.localWrites
      | .monotonic => fun _ => none
    { s with published := some view }

def writerPrefix (p : Protocol) (inputs : Slot → UInt8) (steps : Nat) : State :=
  (p.writer.take steps).foldl (write inputs) initial

/-- A reader can see the initial flag even when publication is concurrent. -/
inductive FlagSource where | initial | publisher deriving DecidableEq

def flagView (s : State) : FlagSource → Option View
  | .initial => none
  | .publisher => s.published

inductive Result where | notReady | entry (value : UInt8) | unprotectedRead
  deriving DecidableEq, Repr

def readEntry (order : LoadOrder) (slot : Slot) (flag : Option View) : Result :=
  match flag with
  | none => .notReady
  | some view => match order with
    | .monotonic => .unprotectedRead
    | .acquire => match view slot with
      | none => .unprotectedRead
      | some value => .entry value

/-- For either slot, at any point in the writer's execution, a reader that
sees the published flag gets the byte the writer put there. A reader that
sees the initial flag returns early and never reads the table. -/
def Safe (p : Protocol) : Prop :=
  ∀ (inputs : Slot → UInt8) (steps : Nat) (source : FlagSource) (slot : Slot),
    let flag := flagView (writerPrefix p inputs steps) source
    readEntry p.reader slot flag = if flag.isSome then .entry (inputs slot) else .notReady

theorem publication_safe : Safe publication := by
  intro inputs steps source slot
  cases source <;> cases steps with
  | zero => rfl
  | succ n =>
    cases n with
    | zero => rfl
    | succ n =>
      cases n <;> cases slot <;>
        simp [flagView, writerPrefix, publication, List.take, initial, write, readEntry]

theorem after_publication (inputs : Slot → UInt8) (slot : Slot) :
    readEntry publication.reader slot
      (flagView (writerPrefix publication inputs 3) .publisher) = .entry (inputs slot) := by
  cases slot <;> rfl

end Compiler.ZigAir.AtomicPublication
