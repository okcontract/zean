/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.MemoryCallVerification

namespace Compiler.ZigAir.MemoryCall
open Memory MemoryAir.Verify Std.WP

/-- Clients can expose a simpler result contract without repeating execution
reasoning. The exceptional outcomes and invocation cleanup remain unchanged. -/
theorem BodyContract.weaken
    (checked : BodyContract program args invariants initial post errors)
    (implies : ∀ value after, post value after → weaker value after) :
    BodyContract program args invariants initial weaker errors := by
  exact ⟨checked.entails_wp_of_post
    (finishPost_mono _ _ _ _ _ _ implies (fun _ _ h => h))⟩

end Compiler.ZigAir.MemoryCall
