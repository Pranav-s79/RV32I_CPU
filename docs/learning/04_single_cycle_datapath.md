# 04. The Single-Cycle Datapath

## What happens in one instruction cycle

The current core completes each valid instruction in one architectural cycle.
The work is combinational between clock edges:

1. The PC addresses instruction memory.
2. The decoder splits the instruction into fields and the control unit selects
   an operation.
3. The register file reads source operands while the immediate generator
   reconstructs any constant.
4. The ALU, branch unit, and next-PC logic compute results and control flow.
5. Loads pass through the load/store formatter; stores generate write data and
   byte enables.
6. The writeback mux selects a value for `rd`.
7. At the rising edge, the PC and any architectural destination state update.

This is easy to reason about because no instruction depends on another
instruction partway through the cycle. Its weakness is the long clock path: a
load may travel through fetch, decode, register read, address calculation,
data memory, load formatting, and writeback before the edge.

## Datapath blocks

| Block | Responsibility | Repository module |
|-------|----------------|-------------------|
| PC | Current instruction address and sequential update | `program_counter` |
| Decoder | Split raw instruction fields | `instruction_decoder` |
| Control | Produce explicit operation controls and detect illegal forms | `control_unit` |
| Immediate generator | Build I/S/B/U/J signed constants | `immediate_generator` |
| Register file | Two asynchronous reads, one clocked write; preserve x0 | `register_file` |
| ALU | Arithmetic, logic, shifts, signed/unsigned set-less-than | `alu` |
| Branch unit | Compare branch operands | `branch_unit` |
| Next-PC logic | Choose PC+4, branch/JAL target, or JALR target | `next_pc_logic` |
| Load/store unit | Byte lanes, data shifting, extension and alignment | `load_store_unit` |
| Core | Connect datapath; gate side effects on exceptions | `rv32i_core` |

## Control is the instruction's plan

The control unit turns an instruction into a bundle of decisions: whether to
write a register, which ALU operation to use, whether an operand is an
immediate, whether memory is read or written, and which result is written
back. Explicit controls are easier to inspect than scattering opcode checks
through the datapath. They can later travel with an instruction through
pipeline registers.

For example, an `ADDI rd, rs1, imm` reads `rs1`, selects the I-immediate as ALU
operand B, adds, and writes the ALU result to `rd`. An `LW` uses the ALU to
calculate an address, reads memory, formats the selected bytes, and writes the
load value. A branch compares two registers and may change the PC but writes no
register.

## Commit and precise halt behavior

The core's `commit` is true when the current instruction is valid and raises
no exception. Register and memory writes are gated by commit. On an illegal
instruction, bad address, or other supported exception, the instruction does
not update architectural state; the core records trap information and halts.
This makes the single-cycle core a useful reference for later implementations.

## Check your understanding

1. Which blocks are on the critical path for a load?
2. Why does an `ADD` need register-file reads but no immediate generation?
3. Why must the store write-enable be disabled when an exception occurs?
4. How can explicit control signals make the later pipeline easier to design?

## In this repository

Follow the diagram and signal descriptions in [`../architecture.md`](../architecture.md).
Then trace `ADDI`, `LW`, `SW`, `BEQ`, `JAL`, and `JALR` in
[`../instruction_walkthrough.md`](../instruction_walkthrough.md).
