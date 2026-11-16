// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 OKcontract Pte. Ltd.
//! Independent expression DAG fixtures and expected encodings. build.zig writes
//! these controls to a temporary Lean module and checks it after the libraries.

pub const source =
    \\/- Generated transient controls from test/lean/declaration_encoding.zig by build.zig. -/
    \\/-
    \\// SPDX-License-Identifier: Apache-2.0
    \\// Copyright (C) 2026 OKcontract Pte. Ltd.
    \\-/
    \\import Contract.Check.Declarations
    \\
    \\namespace Compiler.DeclarationEncodingTests
    \\open Lean Contract.Check.Declarations
    \\
    \\private def expectEncoding (term : Expr) (expected : Json) : IO Unit := do
    \\  let actual := expression term
    \\  unless actual == expected do
    \\    throw <| IO.userError s!"expression encoding changed: {actual.compress} != {expected.compress}"
    \\
    \\-- Expected postorder nodes are recorded independently of the interning code.
    \\-- Repeated subterms must share their node IDs rather than duplicate nodes.
    \\#eval expectEncoding (.app (.app (.const `Nat.add []) (.lit (.natVal 2))) (.mdata {} (.lit (.natVal 2)))) <|
    \\    Json.mkObj [
    \\      ("encoding", .str "kernelExprDag-v1"), ("root", toJson (3 : Nat)),
    \\      ("nodes", .arr #[
    \\        .arr #[.str "const", .str "Nat.add", .arr #[]],
    \\        .arr #[.str "natural", .str "2"],
    \\        .arr #[.str "app", toJson (0 : Nat), toJson (1 : Nat)],
    \\        .arr #[.str "app", toJson (2 : Nat), toJson (1 : Nat)]])]
    \\
    \\-- Metadata is omitted even when it occurs within a shared expression.
    \\example (term : Expr) (metadata : MData) :
    \\    expression (.mdata metadata term) = expression term := rfl
    \\
    \\-- Binder names, binder annotations, let annotations and projection identities
    \\-- remain in the encoding, and every recursive constructor visits children first.
    \\#eval expectEncoding (.lam `x (.const `Nat [])
    \\      (.forallE `y (.sort .zero)
    \\        (.letE `z (.const `Nat []) (.lit (.natVal 7))
    \\          (.proj `Prod 1 (.app (.bvar 1) (.bvar 0))) false) .implicit) .default) <|
    \\    Json.mkObj [
    \\      ("encoding", .str "kernelExprDag-v1"), ("root", toJson (9 : Nat)),
    \\      ("nodes", .arr #[
    \\        .arr #[.str "const", .str "Nat", .arr #[]],
    \\        .arr #[.str "sort", .arr #[.str "zero"]],
    \\        .arr #[.str "natural", .str "7"],
    \\        .arr #[.str "bound", .str "1"],
    \\        .arr #[.str "bound", .str "0"],
    \\        .arr #[.str "app", toJson (3 : Nat), toJson (4 : Nat)],
    \\        .arr #[.str "projection", .str "Prod", .str "1", toJson (5 : Nat)],
    \\        .arr #[.str "let", .str "z", toJson (0 : Nat), toJson (2 : Nat), toJson (6 : Nat), .bool false],
    \\        .arr #[.str "forall", .str "y", .str "implicit", toJson (1 : Nat), toJson (7 : Nat)],
    \\        .arr #[.str "lambda", .str "x", .str "explicit", toJson (0 : Nat), toJson (8 : Nat)]])]
    \\
    \\end Compiler.DeclarationEncodingTests
;
