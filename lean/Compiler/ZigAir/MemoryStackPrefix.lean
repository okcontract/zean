/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryStackLaws
import Compiler.ZigAir.MemoryByteAccessProofs

/-! Word and byte views under an invocation-owned stack prefix. -/
namespace Compiler.ZigAir.Memory

namespace WordArray

theorem writable_heap_eq (before after : State) (view : View) (same : after.heap = before.heap)
    (cap : Writable before view) : Writable after view := by
  simpa only [Writable, same] using cap

theorem represents_heap_eq (before after : State) (view : View) (items : List (BitVec 32))
    (same : after.heap = before.heap) (represented : Represents before view items) : Represents after view items := by
  refine ⟨represented.1, ?_⟩
  intro index inside
  exact (load_eq_of_lookup before after true false word (view.address index) (by rw [same])).trans
    (represented.2 index inside)

end WordArray

namespace WordByteView

theorem read_prepend (order : WordBytes.Order) (state : State) (id : Nat) (cell : Allocation)
    (nextId nextAddress : Nat) (writable many : Bool) (address : Address) (offset : Nat)
    (apart : address.allocation ≠ id) :
    read order (prepend id cell nextId nextAddress state) (.pointer (.pointer writable many WordArray.word) address) offset =
      read order state (.pointer (.pointer writable many WordArray.word) address) offset := by
  simp only [read, load_prepend state id cell nextId nextAddress writable many WordArray.word address apart]

theorem write_prepend (order : WordBytes.Order) (state : State) (id : Nat) (cell : Allocation)
    (nextId nextAddress : Nat) (writable many : Bool) (address : Address) (offset : Nat) (byte : BitVec 8)
    (apart : address.allocation ≠ id) :
    write order (prepend id cell nextId nextAddress state) (.pointer (.pointer writable many WordArray.word) address) offset byte =
      (write order state (.pointer (.pointer writable many WordArray.word) address) offset byte).map (prepend id cell nextId nextAddress) := by
  simp only [write, load_prepend state id cell nextId nextAddress writable many WordArray.word address apart]
  split
  · split
    · rfl
    · exact store_prepend state id cell nextId nextAddress writable many WordArray.word address _ apart
    · rfl
  · rfl

end WordByteView

namespace ByteAccess

theorem read_prepend (order : WordBytes.Order) (state : State) (id : Nat) (cell : Allocation)
    (nextId nextAddress : Nat) (writable many : Bool) (address : Address) (apart : address.allocation ≠ id) :
    read order (prepend id cell nextId nextAddress state) (pointer writable many address) =
      read order state (pointer writable many address) := by
  simp only [read, pointer, byte, WordByteView.read, wordPointer]
  rw [load_prepend state id cell nextId nextAddress writable false WordArray.word (wordAddress address) apart]

theorem write_prepend (order : WordBytes.Order) (state : State) (id : Nat) (cell : Allocation)
    (nextId nextAddress : Nat) (writable many : Bool) (address : Address) (value : Value)
    (apart : address.allocation ≠ id) :
    write order (prepend id cell nextId nextAddress state) (pointer writable many address) value =
      (write order state (pointer writable many address) value).map (prepend id cell nextId nextAddress) := by
  simp only [write, pointer, byte]
  split
  next bits =>
    split
    · rfl
    · simp only [WordByteView.write, wordPointer]
      split
      next inside =>
        rw [load_prepend state id cell nextId nextAddress writable false WordArray.word (wordAddress address) apart]
        split
        · rfl
        · exact store_prepend state id cell nextId nextAddress writable false WordArray.word (wordAddress address) _ apart
        · rfl
      · rfl
  · rfl

end ByteAccess
end Compiler.ZigAir.Memory
