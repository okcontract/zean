import Parity.Generated
import Compiler.ZigAir.MemoryCallMachine

namespace Parity
open Compiler.ZigAir Memory MemoryCallMachine

theorem even_four :
    run Generated.functions 200 Generated.FunctionId.fn_is_even [.scalar (.int false 64 4)] {} =
      .finished (.ok (.scalar (.bool true))) {} := rfl

theorem odd_five :
    run Generated.functions 200 Generated.FunctionId.fn_is_even [.scalar (.int false 64 5)] {} =
      .finished (.ok (.scalar (.bool false))) {} := rfl

end Parity
