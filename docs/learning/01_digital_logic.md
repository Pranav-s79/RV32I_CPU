# 01. Digital Logic and Clocks

## A bit is a circuit value

Digital hardware represents information with bits: `0` and `1`. A group of
bits is a vector. For an unsigned `N`-bit vector, the representable range is
`0` through `2^N - 1`. A 32-bit register therefore holds 32 bits, not an
unbounded mathematical integer.

Boolean operations combine bits:

- AND is 1 only when both inputs are 1.
- OR is 1 when either input is 1.
- XOR is 1 when the inputs differ.
- NOT flips a bit.

An adder combines Boolean gates into a circuit that computes a sum. Hardware
does not execute a software statement one step at a time: the gates settle in
parallel after their inputs change.

## Combinational and sequential logic

**Combinational logic** has no stored state. Its outputs depend on its current
inputs. The ALU, immediate generator, branch comparator, and muxes in this
project are combinational.

**Sequential logic** stores state and updates it at a clock edge. The PC,
register file writes, data-memory writes, and trap status are sequential. A
typical register is described by `always_ff @(posedge clk)` and uses
nonblocking assignments (`<=`).

The CPU is a state machine. At the start of a cycle it has a PC and registers.
Combinational logic calculates the next values. On the rising edge the state
captures those values. The next cycle begins with the new state.

## Clocks, reset, and timing

A clock is a repeating signal that defines when state changes. A synchronous
reset is sampled at a clock edge; an asynchronous reset can change state
without waiting for an edge. This repository's single-cycle PC and core use a
synchronous active-high reset. Reset conventions must match across connected
modules.

Signals do not change instantaneously. After a register launches a value, it
passes through logic and wiring before another register captures it. The
clock period must be long enough for the slowest register-to-register path,
including setup time and routing delay. If the clock is too fast, the captured
value may be wrong.

**Setup time** is how long data must be stable before the capture edge.
**Hold time** is how long it must remain stable afterward. Static timing
analysis checks these relationships for paths in the implemented FPGA.

## FPGA building blocks

- A **LUT** implements a small truth table. LUTs form Boolean logic and can
  implement small ROMs or distributed RAM.
- A **flip-flop (FF)** stores one bit across clock edges.
- **Block RAM (BRAM)** is a dense memory resource. It usually has clocked,
  registered reads, so it does not behave like the current Phase 1
  combinational-read memories.
- Routing connects resources. A design with few logic levels can still be slow
  if its wires are long or heavily loaded.

## Check your understanding

1. Why does a combinational ALU not need a clock input?
2. Why must a PC be stored in sequential state?
3. What happens if a value reaches a destination register after its capture
   edge?
4. Why can a small asynchronous memory use LUTs instead of BRAM?

## In this repository

Start with [`rtl/program_counter.sv`](../../rtl/program_counter.sv),
[`rtl/alu.sv`](../../rtl/alu.sv), and the clock-path discussion in
[`../baseline.md`](../baseline.md).
