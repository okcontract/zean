/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryCallMachineAutomation
import Compiler.ZigAir.MemoryCallMachineBindings

/-! Data-based calls, exact resumption and checked procedure summaries through
Std.WP. `verify` accepts client loop invariants and `machine_vcgen` handles
branches, blocks, loops and calls using atomic memory rules. `ofMemory_contract`
transfers existing intraprocedural proofs through the exact interpreter adapter. -/
