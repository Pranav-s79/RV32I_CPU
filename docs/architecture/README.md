# Architecture Notes

Beginner overview written in Phase 0. The blocks below are now implemented (Phase 1). For the detailed, current design see [`../architecture.md`](../architecture.md).

## From C program to hardware

```
C program               software/*.c
   ↓
RISC-V compiler         riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32
   ↓
RISC-V machine code     32-bit instructions (e.g. 0x00b50533 = add a0, a0, a1)
   ↓
Instruction memory      the CPU reads one instruction at a time from here
   ↓
RV32I CPU               SystemVerilog in rtl/, executes each instruction
   ↓
FPGA hardware           Vivado turns the RTL into a circuit on the Zynq XC7Z010
```

The top half is **software** (programs). The bottom half is **hardware** (the machine that runs them).

## Main CPU blocks (future)

In a single-cycle CPU, every instruction passes through all of these in one clock cycle.

| Block | What it does |
|-------|--------------|
| **Program Counter (PC)** | A 32-bit register holding the address of the current instruction. Normally goes to `PC + 4` each cycle; branches and jumps load a different address. |
| **Instruction Memory** | Holds the program. Given the PC, it outputs the 32-bit instruction at that address. |
| **Control Unit** | Reads the instruction's opcode (and `funct3`/`funct7`) and sets the control signals: which ALU operation, whether to write a register, whether to read/write memory, whether to branch. |
| **Register File** | The 32 general-purpose registers `x0`–`x31`. Reads two registers (`rs1`, `rs2`) and writes one (`rd`). `x0` always reads as zero. |
| **Immediate Generator** | Pulls the constant (immediate) out of the instruction and sign-extends it to 32 bits. Each instruction format (I, S, B, U, J) packs its bits differently. |
| **ALU** | Arithmetic Logic Unit. Does the math and logic: add, subtract, AND, OR, XOR, shifts, and comparisons. Also computes memory addresses. |
| **Data Memory** | RAM for `lw`/`sw` (and byte/halfword variants). Separate from instruction memory in this design. |
| **Write Back** | Chooses what gets written to the destination register: the ALU result, a value loaded from memory, or `PC + 4` (for jumps). |

## Basic single-cycle flow

```
PC → Instruction Memory → instruction
                            ├─→ Control Unit → control signals
                            ├─→ Register File (read rs1, rs2)
                            └─→ Immediate Generator
Register values / immediate → ALU → result
ALU result → Data Memory (loads/stores)
Result / loaded data / PC+4 → Write Back → Register File (write rd)
Next PC = PC + 4, or branch/jump target
```

Detailed description of the implemented design: [`../architecture.md`](../architecture.md).
