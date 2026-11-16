/-
Copyright (C) 2026 OKcontract Pte. Ltd.
SPDX-License-Identifier: Apache-2.0
Generated from admitted AIR; do not edit.
Source validity and native refinement require separate evidence.
-/
-- Source SHA-256: 8a84ab73835e2efd0ee5ab267106b88600f1957b3714fbab5d0def7535967166
-- Capture report SHA-256: bc2b944729aa795bb81027bacb2b1d2a0dc889cb6add1f38533b8905d0381574
import Compiler.ZigAir.MemoryAir

namespace «Compiler».«Tutorial».«Buffer».«V2».«Generated»
open Compiler.ZigAir.MemoryAir

-- AIR SHA-256: 8f4dde283301053fd13aece2b8d7b2f49c7aa6f0c13731f4cba465f64b763dfa
def fn_replace : Program :=
{ parameters := [(.pointer true true (.scalar (.int false 32))), (.scalar (.int false 64)), (.scalar (.int false 64)), (.scalar (.int false 32))], returnType := (.scalar .bool), body :=
  (.bind 0 (.pointer true true (.scalar (.int false 32)))
  (.argument 0)
  (.bind 1 (.scalar (.int false 64))
  (.argument 1)
  (.bind 2 (.scalar (.int false 64))
  (.argument 2)
  (.bind 3 (.scalar (.int false 32))
  (.argument 3)
  (.bind 4 (.pointer true false (.pointer true true (.scalar (.int false 32))))
  (.alloc (.pointer true true (.scalar (.int false 32))))
  (.bind 5 (.scalar .unit)
  (.store (.local 4) (.local 0))
  (.bind 6 (.pointer false false (.pointer true true (.scalar (.int false 32))))
  (.pointerCast (.pointer false false (.pointer true true (.scalar (.int false 32)))) (.local 4))
  (.block 7 (.scalar .unit)
  (.bind 8 (.scalar (.int false 64))
  (.scalar (.cast .bitcast (.int false 64) (.local 2)))
  (.bind 9 (.scalar (.int false 64))
  (.scalar (.cast .bitcast (.int false 64) (.local 1)))
  (.bind 10 (.scalar .bool)
  (.scalar (.comparison .ge (.local 8) (.local 9)))
  (.branch (.local 10)
  (.ret (.constant (.scalar (.bool false))))
  (.jump 7 (.constant (.scalar .unit)))))))
  (.bind 14 (.pointer true true (.scalar (.int false 32)))
  (.load (.local 6))
  (.bind 15 (.pointer true false (.scalar (.int false 32)))
  (.elementPointer (.local 14) (.local 2))
  (.bind 16 (.scalar .unit)
  (.store (.local 15) (.local 3))
  (.ret (.constant (.scalar (.bool true))))))))))))))) }

end «Compiler».«Tutorial».«Buffer».«V2».«Generated»
