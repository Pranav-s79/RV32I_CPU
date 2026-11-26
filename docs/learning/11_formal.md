# 11. Formal Verification

## Simulation versus formal

Simulation checks selected input sequences. Formal tools explore a modeled
state space and try to prove properties for all states and inputs allowed by
the assumptions. A proof is only as strong as its model and assumptions; an
assumption that excludes difficult behavior can make a false design appear
correct.

Formal verification complements, rather than replaces, simulation. Simulation
is often easier for full programs and software integration. Formal methods are
strong for local invariants, corner cases, and bounded control sequences.

## Assertions and invariants

An assertion states a property that must always hold. Examples for this CPU
include:

- x0 always reads zero;
- a flushed instruction never writes a register or memory;
- a valid instruction retires at most once;
- a load-use stall holds the PC and fetch/decode entry;
- a taken branch eventually redirects to its target under the stated
  assumptions;
- a store uses byte enables consistent with its size and offset.

Safety properties say something bad never happens. Liveness properties say
something good eventually happens, usually with assumptions that the memory or
environment eventually responds.

## Bounded proof and uninitialized state

Bounded model checking explores behavior for a finite number of cycles. A
counterexample gives an input/state sequence that violates a property. If no
counterexample is found within the bound, the result is not automatically an
unbounded proof. Initialization, reset assumptions, memory abstraction, and
fairness conditions must be stated and reviewed.

## RVFI

The RISC-V Formal Interface (RVFI) describes architectural effects of retired
instructions: instruction order, PC before/after, register reads/writes, and
memory effects. A standard interface lets a formal framework compare the core
against ISA properties without depending on its internal pipeline structure.

For a pipeline, RVFI-style retirement also helps keep correctness separate
from timing: the microarchitecture may take more cycles while preserving the
same instruction-level results.

## Check your understanding

1. What does a counterexample provide?
2. How can an over-strong assumption hide a bug?
3. Why is a 20-cycle bounded proof different from an unbounded proof?
4. Which architectural values should a retirement interface expose?

## In this repository

Formal verification is a planned phase. The current
[`../verification.md`](../verification.md) lists known verification gaps.
Keep synthesizable RTL conservative and record tool limitations and all
assumptions alongside any proof result.
