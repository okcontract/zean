// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.

pub const source =
    \\import Compiler.ZigAir.ProofAudit
    \\open Lean Compiler.ZigAir.ProofAudit
    \\
    \\run_cmd do
    \\  let actual ← theoremAxioms #[
    \\    (#["Nat.add_zero"], #["Init.Core"]),
    \\    (#["Classical.em", "Nat.add_zero"], #["Init.Classical", "Init.Core"])]
    \\  let expected := Json.mkObj [
    \\    ("Nat.add_zero", .arr #[]),
    \\    ("Classical.em", toJson #["Classical.choice", "Quot.sound", "propext"])]
    \\  unless actual == expected do throwError "unexpected theorem axioms: {actual}"
    \\
    \\theorem trivialCopy (bytes : Nat) : bytes = bytes := rfl
    \\theorem renamedCopy (count : Nat) : count = count := rfl
    \\theorem conditionalCopy (bytes : Nat) (_ : bytes > 0) : bytes = bytes := rfl
    \\
    \\run_cmd do
    \\  let signatures ← theoremStatements ["trivialCopy", "renamedCopy", "conditionalCopy"]
    \\  let first := signatures.getObjValD "trivialCopy"
    \\  unless first != Json.null && first == signatures.getObjValD "renamedCopy" &&
    \\      first != signatures.getObjValD "conditionalCopy" do throwError "incorrect theorem statement identity"
    \\
    \\-- A shared theorem must pass the origin check for every manifest naming it.
    \\/-- error: theorem Nat.add_zero is not declared in a checked client proof module -/
    \\#guard_msgs in
    \\run_cmd do
    \\  discard <| theoremAxioms #[
    \\    (#["Nat.add_zero"], #["Init.Core"]), (#["Nat.add_zero"], #["Init.Classical"])]
;
