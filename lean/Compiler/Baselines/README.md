# Verification baselines

`BufferExecution.lean` retains the historical instruction-by-instruction buffer
proof for regression and proof-effort comparisons. It imports the tutorial's
inputs and contracts; the active tutorial does not import this baseline.
Its declaration namespace is preserved to keep historical theorem names stable.

The complete Lean build checks this file. Fresh tutorial proof replay explicitly
rejects importing it, so the active proof must use the generic verification
framework. See the [verification guide](../../../docs/verification.md) for what
the comparison measures.
