/- SPDX-License-Identifier: Apache-2.0 -/
import Compiler.Tutorial.Ziglings.Controls
open Compiler.Tutorial.Ziglings Compiler.Tutorial.Ziglings.Controls
set_option maxRecDepth 4096

-- Expected rejection: a fabricated length cannot make the extra byte readable.
example : oversized.1 = .ok (byte 0) := by rfl
