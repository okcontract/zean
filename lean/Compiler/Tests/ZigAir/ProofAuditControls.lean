/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
-/
import Compiler.ZigAir.ProofAudit

namespace Compiler.Tests.ZigAir.ProofAuditControls
theorem checked : True := True.intro
#audit_proof "Compiler.Tests.ZigAir.ProofAuditControls.checked"

/-- error: expected a checked theorem: Compiler.Tests.ZigAir.ProofAuditControls.missing -/
#guard_msgs in
#audit_proof "Compiler.Tests.ZigAir.ProofAuditControls.missing"

/-- error: expected a checked theorem: Classical.choice -/
#guard_msgs in
#audit_proof "Classical.choice"

/-- error: theorem Compiler.Tests.ZigAir.ProofAuditControls.checked is not declared in a checked client proof module -/
#guard_msgs in
#audit_proof "Compiler.Tests.ZigAir.ProofAuditControls.checked" from ["Unrelated"]

/-- error: theorem Nat.add_comm is not declared in a checked client proof module -/
#guard_msgs in
#audit_proof "Nat.add_comm" from ["Unrelated"]
end Compiler.Tests.ZigAir.ProofAuditControls
