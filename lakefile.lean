/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Lake
open Lake DSL

package zean where
  leanOptions := #[⟨`warningAsError, true⟩]

lean_lib Contract where
  srcDir := "lean"
  globs := #[.submodules `Contract]

@[default_target]
lean_lib Compiler where
  srcDir := "lean"
  -- Full release coverage includes every framework, client, capture and control.
  -- build.zig also exposes narrower development scopes using explicit modules.
  globs := #[.submodules `Compiler]
