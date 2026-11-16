/- SPDX-License-Identifier: Apache-2.0 -/
import Compiler.Tutorial.Ziglings.Controls
open Compiler.ZigAir.Memory Compiler.Tutorial.Ziglings.Controls
set_option maxRecDepth 4096

-- Expected rejection: omitting the second initialization does not return gold.
example : missing.1 = .ok (WordArray.number 10) := by rfl
