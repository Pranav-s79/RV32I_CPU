# 03. RISC-V and the RV32I ISA

## ISA versus microarchitecture

An **instruction set architecture (ISA)** is the contract visible to software:
instruction meanings, registers, memory behavior, and control flow. A
**microarchitecture** is the hardware organization used to implement that
contract. The single-cycle and future pipelined cores can have very different
internal timing while executing the same architectural instruction stream.

RV32I means the base integer ISA with 32-bit registers and addresses. The core
uses 32 architectural integer registers, `x0` through `x31`. Reading `x0`
always returns zero; writes to it are ignored. Instructions are 32 bits wide,
and normal sequential execution advances the PC by 4.

## Instruction fields

An instruction is a 32-bit word. Common fields are:

| Field | Bits | Role |
|-------|------|------|
| `opcode` | `[6:0]` | Broad instruction class |
| `rd` | `[11:7]` | Destination register |
| `funct3` | `[14:12]` | Operation subtype |
| `rs1` | `[19:15]` | First source register |
| `rs2` | `[24:20]` | Second source register |
| `funct7` | `[31:25]` | Further operation selection |

The fields have different meanings for different formats:

- **R-type:** register-register arithmetic, with `rd`, `rs1`, and `rs2`.
- **I-type:** arithmetic immediate, loads, and JALR. Its immediate is
  `instruction[31:20]`, sign-extended to 32 bits.
- **S-type:** stores. Its immediate is split between `[31:25]` and `[11:7]`.
- **B-type:** conditional branches. Its signed byte offset is scattered across
  the instruction and has a low zero bit.
- **U-type:** LUI and AUIPC. The upper 20 instruction bits are shifted left by
  12.
- **J-type:** JAL. Its signed byte offset is split across four instruction
  slices and has a low zero bit.

Never assume that a bit slice has one fixed meaning across formats. The
immediate generator reconstructs each format separately.

## Arithmetic and comparisons

Integer register results are 32-bit values. Addition wraps modulo `2^32`:
`0xffff_ffff + 1` produces `0`. Two's-complement signed values reuse the same
bits; signedness changes comparisons, not the bit-level adder.

- `SLT` compares signed values; `SLTU` compares unsigned values.
- `SRA` copies the sign bit as it shifts; `SRL` shifts in zeros.
- Branches include equality/inequality and signed/unsigned less-than and
  greater-or-equal comparisons.

## Control flow

For ordinary instructions, `next_pc = pc + 4`. A taken branch uses `pc +
branch_offset`. `JAL` writes `pc + 4` to `rd` and jumps to `pc + offset`.
`JALR` writes `pc + 4` and jumps to `(rs1 + immediate) & ~1`, clearing target
bit 0. The current implementation checks instruction alignment and halts on
exceptions rather than using a privileged trap handler.

## Loads and stores

Loads and stores calculate a byte address using `rs1 + sign_extended_offset`.
Loads include signed byte/half/word (`LB`, `LH`, `LW`) and unsigned byte/half
(`LBU`, `LHU`). Stores include `SB`, `SH`, and `SW`. The data path must select
the correct byte lanes and sign- or zero-extend loaded values.

## Scope

The current core implements RV32I and selected system instructions used for
controlled termination (`ECALL`, `EBREAK`) and `FENCE`. It does not implement
compressed instructions, multiply/divide, floating point, CSRs, privilege
modes, interrupts, or trap handlers. Unsupported encodings halt as illegal
instructions.

## Check your understanding

1. Why does writing `x0` not change later reads of `x0`?
2. Why are B-type and J-type immediates reconstructed instead of read as one
   contiguous slice?
3. What is different between `SLT` and `SLTU` if their input bits are the
   same?
4. What value does JALR put in `rd`, and why is target bit 0 cleared?

## In this repository

Use [`../instruction_walkthrough.md`](../instruction_walkthrough.md) and
[`../architecture.md`](../architecture.md). Instruction-specific examples are
in [`../../tests/programs/rv32i_full.S`](../../tests/programs/rv32i_full.S).
