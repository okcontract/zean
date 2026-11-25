# Explicit call-stack execution

Call profiles emit each body as a `Function` and the complete table as
`functions`. `FunctionId.fn_name` names the index used by calls and proofs.
Suspension retains the environments, continuations, and lifetime marks.
`advance_add` proves that resuming two budgets agrees with running their sum.
In the generated file, captured records and the certificate follow the
function definitions.

```sh
zig build run -- translate --capture /path/to/capture/report.json \
  --root calls.update --profile calls \
  --certify /tmp/calls-certificate --output /tmp/calls-model
```

`--call-machine` can explicitly assert a call profile. The acyclic profiles
use `CapturedCallMachine.decode`. `recursive-calls` uses `decodeRecursive`
to check calls anywhere in the table, including self and mutual calls. Both
check the captured bodies and require unique declarations with matching
source identities, arities, and return types. Translation checks runtime
argument types as well. [Profile limits](architecture.md#supported-routes)

A direct call to a generic specialization can supply a named `comptime`
function. Zean checks the callback's source identity and the owner's
function-typed parameter while building the runtime parameter map. The
certificate interprets the concrete AIR after specialization, with each
reached call checked against its own captured declaration.

`MemoryCallMachine.run functions fuel root args state` returns a finished
result or a suspended configuration. The default `.history` policy keeps
address accounting. Pass `.reuse` to reclaim storage at invocation boundaries.
Both policies keep lifetime IDs fresh, so cleanup leaves dangling returns
invalid.

## Checked summaries and VC generation

Import `Compiler.ZigAir.Verify.Machine`. `invoke functions root args` gives
a verification action over the interpreter. Its WP covers every finite
observation, including callee faults. `sound` connects the triple to
`advance`, and `safe_of_spec` derives memory safety when the fault
postcondition allows only `.outOfMemory`.

`Contract.apply` uses a callee's proved summary in the caller. The composition
theorem attaches the real continuation and preserves reached writes, fault
cleanup, result typing, and suspension under both resource policies.
[Caller and helper proof](../examples/client/calls/README.md)

Use `verify functions root args invariants` for structured control. It
describes the same invocation and selects proof rules for the supplied
invariants. `machine_vcgen` generates goals for instructions, branches,
blocks, jumps, loops, calls, and returns. Each back edge must reestablish
the invariant. Breaks carry the current locals and memory to the matching
block. Call continuations use the actual returned value after the call
transition. `machine_normalize` unfolds client definitions for the memory
tactics. [Byte scan proof](../examples/client/scan/README.md)

`verify_at` selects a body with a proved table lookup. `invariant_spec`
supports manual execution invariants. `ofMemory_contract` transfers a
finite or looping intraprocedural contract using exact execution equivalence,
including faults, cleanup and suspension. `ofMemory_contract_at` handles a
checked entry in a larger table. [Buffer adapter](../lean/Compiler/Tutorial/Buffer/Machine.lean)

`MemoryCallMachine.effects` preserves heap validity and existing allocation
metadata across success, faults and suspension. `rootWritable_retained`
preserves writable root capabilities under either policy. Use the function
contract for contents and initialization guarantees.
[Checked local bindings](verification.md#checked-local-bindings)

## Termination of finite closures

Import `Compiler.ZigAir.MemoryCallMachineTermination`. `Finite.infer`
proposes transition costs for loop-free bodies and their callees.
`Finite.Valid` checks those costs, and `Finite.terminates` proves termination
for arbitrary inputs and states, including runs that finish with a fault.

A finite helper can be certified even when another body in the table loops.
A loop or recursive cycle needs a separate progress proof. The costs bound
model transitions. Native timing and stack use need separate evidence.
[Calls termination proof](../lean/Compiler/Tutorial/Calls/Proofs.lean)

## Validation

Fresh captures checked the three-function `calls.update` chain and the byte
scan with a loop, early return, and helper call. Both passed correspondence,
native object comparison, and proof replay. The inclusive-bound scan fails
the original proof, and a separate witness shows the reached fault after a
helper call and back edge.

Controls cover missing and duplicate call identities, forward calls, callee
suspension, fault unwinding with reached writes, and dangling returns. The
earlier finite and partial call interpreters are regression models. The
production contracts here use the explicit stack.
[Validation](validation.md) · [Evidence](evidence.md)
