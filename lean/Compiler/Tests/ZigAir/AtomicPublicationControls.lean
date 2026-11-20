/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.AtomicPublication

namespace Compiler.Tests.ZigAir.AtomicPublicationControls
open Compiler.ZigAir.AtomicPublication

private def inputs : Slot → UInt8 | .first => 17 | .second => 42

-- The three mutations each admit a reader that sees one without a safe read.
example : ¬ Safe { publication with reader := .monotonic } := by
  intro h
  have bad := h inputs 3 .publisher .second
  contradiction

example : ¬ Safe { publication with writer :=
    [.entry .first .first, .entry .second .second, .ready .monotonic] } := by
  intro h
  have bad := h inputs 3 .publisher .second
  contradiction

example : ¬ Safe { publication with writer :=
    [.entry .first .first, .ready .release, .entry .second .second] } := by
  intro h
  have bad := h inputs 2 .publisher .second
  contradiction

end Compiler.Tests.ZigAir.AtomicPublicationControls
