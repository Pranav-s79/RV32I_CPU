# Phase 1 Architecture: Single-Cycle RV32I CPU

This document describes the processor in `rtl/`. Every instruction is fetched, decoded, executed, and completed in **one clock cycle**. All state (PC, registers, data memory, trap status) updates together at the rising clock edge.

## 1. The big picture

A single-cycle CPU is one big block of combinational logic between two sets of flip-flops:

```
          rising edge                                            rising edge
              │                                                      │
   ┌──────────▼─────────┐   combinational logic (no clock)   ┌───────▼────────┐
   │ STATE (flip-flops) │ ─────────────────────────────────▶ │ STATE (next)   │
   │  PC                │   fetch → decode → read regs →     │  PC            │
   │  register file     │   ALU → memory → choose result     │  register file │
   │  data memory       │                                    │  data memory   │
   └────────────────────┘                                    └────────────────┘
```

On each edge the state captures whatever the logic computed. The clock period must be long enough for the **slowest** instruction (a load) to travel all the way through the logic. That is the main weakness of single-cycle designs, and the reason Phase 3 pipelines it.

## 2. Block diagram

```
                                       ┌──────────────────────────────────────────────────────┐
                                       │                     rv32i_core                        │
  ┌──────────┐  pc    ┌─────────────┐  │ instr ┌────────────┐ opcode,f3,f7 ┌───────────────┐  │
  │ program_ │───────▶│ instruction │──┼──────▶│instruction_│─────────────▶│ control_unit  │  │
  │ counter  │        │   memory    │  │       │  decoder   │              └──┬────────────┘  │
  └────▲─────┘        │ (ROM, async)│  │       └──┬───┬───┬─┘                 │ control       │
       │              └─────────────┘  │       rs1│rs2│ rd│                   │ signals       │
       │                               │          ▼   ▼   │  ┌───────────┐    │               │
       │                               │      ┌───────────┴┐ │ immediate │◀───┘ imm_type      │
       │                               │      │  register  │ │ generator │                    │
       │                               │      │    file    │ └─────┬─────┘                    │
       │                               │      └──┬──────┬──┘       │ imm                      │
       │                               │   rs1_data  rs2_data      │                          │
       │                               │         │      │          │                          │
       │                               │   ┌─────▼─┐  ┌─▼──────────▼┐                         │
       │                               │   │A mux  │  │   B mux     │ (rs2 or imm)            │
       │                               │   │rs1/pc/│  └──────┬──────┘                         │
       │                               │   │  0    │         │                                │
       │                               │   └───┬───┘         │                                │
       │                               │       └──▶┌─────┐◀──┘      ┌─────────────┐           │
       │                               │           │ ALU │          │ branch_unit │◀ rs1,rs2  │
       │                               │           └──┬──┘          └──────┬──────┘           │
       │                               │   alu_result │                    │ taken            │
       │          ┌──────────────┐     │              ├──────────▶ address │                  │
       │          │ data_memory  │◀────┼── addr ──────┘          ┌─────────▼──────┐           │
       │          │ (RAM, async  │     │  ┌─────────────────┐    │ next_pc_logic  │           │
       │          │  read)       │────▶┼─▶│ load_store_unit │    │ pc+4 / pc+imm /│           │
       │          └──────────────┘     │  │ byte lanes,     │    │ (rs1+imm)&~1   │           │
       │                               │  │ sign extension  │    └───┬────────┬───┘           │
       │                               │  └────────┬────────┘        │next_pc │pc+4           │
       │                               │           │ load_data       │        │               │
       │                               │    ┌──────▼──────────────── ▼────────▼─┐             │
       │                               │    │ writeback mux: ALU / load / pc+4  │──▶ rd_data  │
       │                               │    └───────────────────────────────────┘  (to regs)  │
       └────────────────── next_pc ────┼──────────────────────────────────────────────────────┘
                                       └──────────────────────────────────────────────────────┘
```

The memories sit **outside** `rv32i_core`, in `rv32i_soc_top`. The core talks to them through two ports, so the core can be synthesized and measured on its own.

## 3. Modules

| File | Kind | What it does |
|------|------|--------------|
| `rv32i_pkg.sv` | package | Opcodes, funct3 codes, ALU operation enum, mux-select enums, exception cause codes |
| `program_counter.sv` | sequential | 32-bit PC register; synchronous reset to `RESET_VECTOR`; updates only when `enable` = 1 |
| `instruction_memory.sv` | memory | 4 KiB ROM loaded from a hex file; **combinational** read |
| `instruction_decoder.sv` | wiring | Splits the instruction into `opcode, rd, funct3, rs1, rs2, funct7, funct12` |
| `control_unit.sv` | combinational | Main decoder: control signals + illegal-instruction detection |
| `immediate_generator.sv` | combinational | Builds the sign-extended 32-bit immediate for I/S/B/U/J formats |
| `register_file.sv` | sequential + comb. | 32×32 registers; 2 async read ports, 1 sync write port; x0 = 0 |
| `alu.sv` | combinational | ADD SUB SLL SLT SLTU XOR SRL SRA OR AND |
| `branch_unit.sv` | combinational | Compares rs1/rs2 for BEQ/BNE/BLT/BGE/BLTU/BGEU |
| `next_pc_logic.sv` | combinational | Picks `pc+4`, `pc+imm`, or `(rs1+imm)&~1`; flags misaligned targets |
| `load_store_unit.sv` | combinational | Byte-lane strobes for stores; shifting + sign/zero extension for loads; misalignment detection |
| `data_memory.sv` | memory | 4 KiB RAM; **combinational** read, synchronous byte-masked write |
| `rv32i_core.sv` | top (core) | Connects everything; writeback mux; exception priority; trap/halt registers |
| `rv32i_soc_top.sv` | top (system) | Core + memories + LED register + address decoder |

## 4. Control signals

Generated by `control_unit.sv` from the opcode (and funct3/funct7):

| Instruction | reg_write | alu_a | alu_b | alu_op | imm | mem_read | mem_write | wb_sel | branch | jal | jalr |
|-------------|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| R-type (ADD…) | 1 | rs1 | rs2 | funct3/7 | – | 0 | 0 | ALU | 0 | 0 | 0 |
| I-type (ADDI…) | 1 | rs1 | imm | funct3/7 | I | 0 | 0 | ALU | 0 | 0 | 0 |
| Load | 1 | rs1 | imm | ADD | I | 1 | 0 | MEM | 0 | 0 | 0 |
| Store | 0 | rs1 | imm | ADD | S | 0 | 1 | – | 0 | 0 | 0 |
| Branch | 0 | – | – | – | B | 0 | 0 | – | 1 | 0 | 0 |
| JAL | 1 | – | – | – | J | 0 | 0 | PC+4 | 0 | 1 | 0 |
| JALR | 1 | rs1 | imm | ADD | I | 0 | 0 | PC+4 | 0 | 0 | 1 |
| LUI | 1 | 0 | imm | ADD | U | 0 | 0 | ALU | 0 | 0 | 0 |
| AUIPC | 1 | PC | imm | ADD | U | 0 | 0 | ALU | 0 | 0 | 0 |
| FENCE | 0 | – | – | – | – | 0 | 0 | – | 0 | 0 | 0 |
| ECALL/EBREAK | 0 | – | – | – | – | 0 | 0 | – | 0 | 0 | 0 |

Design choices:

- **Branches do not use the ALU.** `branch_unit` has its own comparators and `next_pc_logic` has its own `pc + imm` adder. This costs one extra 32-bit adder but keeps the ALU's job simple and shortens the branch path.
- **LUI goes through the ALU as `0 + imm`**, so the writeback mux needs only three inputs (ALU, load data, PC+4).
- **JALR uses the ALU** to compute `rs1 + imm`; `next_pc_logic` clears bit 0.

## 5. Instruction execution flow (one cycle)

1. **Fetch:** `pc` addresses instruction memory; the 32-bit instruction appears combinationally.
2. **Decode:** `instruction_decoder` slices the fields; `control_unit` produces control signals; `immediate_generator` builds `imm`; the register file reads `rs1` and `rs2`.
3. **Execute:** operand muxes choose ALU inputs; the ALU computes; `branch_unit` evaluates the condition; `next_pc_logic` computes the next PC.
4. **Memory:** for loads/stores, `alu_result` is the byte address. `load_store_unit` creates strobes/data for stores and extracts/extends load data.
5. **Writeback:** the writeback mux picks ALU result, load data, or `pc+4`.
6. **Exception check:** `rv32i_core` checks all exception conditions in priority order.
7. **Clock edge:** if there is no exception, the PC, register `rd`, and memory are all updated at once. If there is an exception, none of them change and the core halts.

## 6. Memory map and system

| Address range | Device | Access |
|---------------|--------|--------|
| `0x0000_0000 – 0x0000_0FFF` | Instruction memory (4 KiB) | fetch only |
| `0x0001_0000 – 0x0001_0FFF` | Data memory (4 KiB) | load/store |
| `0x8000_0000` | LED register (bits 3:0) | load/store |
| anything else | – | access fault |

- **Reset vector:** `0x0000_0000` (parameter `RESET_VECTOR`).
- **Reset** is synchronous and active high. It resets the PC, the halt/trap registers, and the LED register. The 32 general-purpose registers and data memory are **not** cleared by reset (the RISC-V spec leaves them undefined); they start at zero at power-up/FPGA configuration because of `initial` blocks.
- **Harvard arrangement:** loads/stores cannot read instruction memory, and instructions cannot be fetched from data memory. Programs therefore cannot have initialized `.data`/`.rodata` yet (`build_programs.py` refuses them).
- **No aliasing:** each memory only uses the low address bits, but the SoC decodes the full 32-bit address and raises an access fault for anything outside a device. For example, a store to `0x0001_1000` faults instead of wrapping to `0x0001_0000` (tested by `trap_store_fault`).

## 7. Exceptions, ECALL/EBREAK, FENCE

Phase 1 has **no CSRs, no trap vector, and no privilege modes**. Instead it has a simple, documented halt interface:

- When an instruction raises an exception, it does **not** commit: no register write, no memory write, no PC change.
- The core sets `halted = 1` and holds `trap_cause`, `trap_pc`, and `trap_tval` until reset. Cause numbers match the RISC-V `mcause` encoding.

| Priority | Condition | Cause | trap_tval |
|---------:|-----------|------:|-----------|
| 1 | Fetch from unmapped address | 1 | PC |
| 2 | Illegal instruction | 2 | instruction bits |
| 3 | ECALL | 11 | 0 |
| 4 | EBREAK | 3 | PC |
| 5 | Taken branch/JAL/JALR to a non-4-byte-aligned target | 0 | target |
| 6 | Misaligned load (LH/LHU odd, LW not ×4) | 4 | address |
| 7 | Load from unmapped address | 5 | address |
| 8 | Misaligned store | 6 | address |
| 9 | Store to unmapped address | 7 | address |

- **ECALL and EBREAK are not NOPs.** They halt the core with causes 11 and 3. Test programs end with ECALL and put their result in `a0`.
- **Illegal instructions are not NOPs.** Anything that is not exactly an RV32I encoding traps: unknown opcodes, M/A/F/C-extension encodings, reserved funct3/funct7 values, `FENCE.I`, CSR instructions, `MRET`, `WFI`, and so on.
- **Misaligned accesses trap** rather than being split into two accesses. The spec allows either choice.
- **FENCE** decodes as legal and does nothing. FENCE orders memory accesses as seen by other harts or devices. This core has one hart, executes strictly one instruction at a time in program order, and has no caches, store buffers, or out-of-order memory. Every load or store is finished before the next instruction starts, so the order FENCE asks for already holds. The spec says base implementations must ignore the unused `fm`/`rs1`/`rd` fields, so `FENCE.TSO` is also accepted.

**Limitation:** because there is no `mtvec`/`mepc`/`mret`, software cannot handle a trap and continue. This is not full privileged-architecture compliance. Phase 5 can add Zicsr and a machine-mode trap handler.

## 8. Why the memories are asynchronous (and what that costs)

A single-cycle CPU needs the instruction **in the same cycle** the PC is presented, and load data **in the same cycle** the address is computed. FPGA block RAM (BRAM) only has a registered read: you present the address at one edge and get data after the next edge. Pretending BRAM works in this datapath would be wrong; it would silently add a cycle.

So in Phase 1:

| Memory | RTL style | Expected Vivado mapping |
|--------|-----------|-------------------------|
| Instruction memory | array + `$readmemh`, combinational read, never written | LUT logic (a ROM optimized for the loaded program) |
| Data memory | array, combinational read, clocked byte-masked write | Distributed RAM (LUTRAM) |
| Register file | array, 2 combinational reads, 1 clocked write | Distributed RAM (LUTRAM) |

Consequences:

- Memory sizes stay small (4 KiB each); LUTRAM is limited on the XC7Z010.
- The instruction ROM is built from LUTs and optimized for its contents, so synthesis results depend on the program image. The baseline always uses `tests/programs/rv32i_full.hex`.
- The critical path runs through both memories, which limits clock speed.

**Moving to BRAM (Phase 3+):** in a pipeline, fetch and memory access each get their own stage. A BRAM's registered read then becomes the pipeline register between stages: the PC is sent to BRAM at the end of IF, and the instruction comes out at the start of ID. Data memory works the same way between EX and MEM. Then memories can grow to tens of KiB and come off the critical path.

## 9. Limitations (Phase 1)

- No CSRs (Zicsr), counters, interrupts, trap handlers, or privilege modes.
- No FENCE.I (Zifencei); instruction memory is read-only anyway.
- Misaligned loads/stores trap rather than being emulated.
- No DMEM loader: programs cannot rely on initialized data sections.
- Tiny memories (4 KiB + 4 KiB).
- Not yet run on the physical Zybo board (no board-level top, clocking, or pin constraints yet).
