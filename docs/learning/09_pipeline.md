# 09. Five-Stage Pipelining

## Throughput and latency

A pipeline divides instruction work across stages. The standard five are:

1. **IF:** instruction fetch and PC selection.
2. **ID:** decode, register reads, immediate generation.
3. **EX:** ALU operation, branch decision, address/target calculation.
4. **MEM:** data memory access.
5. **WB:** register-file writeback and architectural retirement.

An instruction takes several cycles from fetch to completion (**latency**),
but after the pipeline fills, independent instructions can complete at a rate
of one per cycle (**throughput**). Stalls and flushes reduce this ideal rate.

## Pipeline registers and valid bits

Registers between stages carry both data and controls. Typical fields include
PC, instruction word, source/destination indices, operand values, immediate,
ALU operation, memory controls, and writeback selection. Use a valid bit at
each boundary. A bubble is an invalid entry; a NOP instruction is valid work
and may retire.

Every state-changing control travels with its instruction. If a wrong-path
instruction is flushed, its register-write and store enables must be inactive.

## Data dependencies and forwarding

An instruction may read a register that an older instruction has not written
back yet. **Forwarding** sends the newer value directly from a later pipeline
stage to the consumer's EX operands. Check the closest producer first, then
older producers. Ignore writes to x0.

Forward each source independently. A false match can use the wrong value; a
missing match may use stale register data. Decode whether an instruction
actually uses `rs1` and `rs2` so immediate bits in those positions do not
create false hazards.

## Load-use stall

An ALU result is available after EX, but a load result comes from memory. If a
dependent instruction reaches EX before the load value is available, the
pipeline must wait. The classic solution is one bubble: hold PC and IF/ID, let
the load advance, and invalidate ID/EX for one cycle. Memory read timing affects
whether the result can be forwarded sooner; define the memory contract first.

## Branches and jumps

With EX resolution, the processor may fetch younger sequential instructions
before learning that a branch is taken. On redirect, set the PC to the target
and invalidate the younger wrong-path entries. A not-taken branch keeps the
sequential path. JAL/JALR link values and target alignment must match Phase 1.

## Exceptions and in-order retirement

An exception found in an early stage cannot simply halt the whole pipeline if
older instructions are still in flight. Carry exception metadata with the
instruction, stop fetching/squash younger work, allow older work to finish,
and suppress the faulting instruction's side effects. Report the trap in
program order. This preserves the existing precise halt contract.

## Measuring a pipeline

`CPI = total_cycles / retired_instructions`. A five-stage pipeline may have a
higher maximum clock but also pay CPI penalties for load-use stalls, redirects,
and memory wait. Approximate throughput is `Fmax / CPI`. Compare retirement
traces to the Phase 1 core while ignoring cycle numbers.

## Check your understanding

1. Why can pipeline throughput approach one instruction per cycle even though
   each instruction takes multiple cycles?
2. Why does the newest matching producer have forwarding priority?
3. What must be held and what must become a bubble during a load-use stall?
4. Which instructions are invalidated after an EX-stage taken branch?
5. Why must trap metadata travel with the faulting instruction?

## In this repository

Read [`../phase_2/README.md`](../phase_2/README.md) and
[`../architecture/pipeline_proposal.md`](../architecture/pipeline_proposal.md).
