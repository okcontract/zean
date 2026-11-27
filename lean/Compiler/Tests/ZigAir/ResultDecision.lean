import Compiler.ZigAir.ResultDecision

-- The unobserved side may contain functions without decidable equality.
example : (Except.ok 7 : Except (Nat → Nat) Nat) = .ok 7 := by decide
example : (Except.error id : Except (Nat → Nat) Nat) ≠ .ok 7 := by decide
example : (Except.error 2 : Except Nat (Nat → Nat)) = .error 2 := by decide
example : (Except.ok id : Except Nat (Nat → Nat)) ≠ .error 2 := by decide
