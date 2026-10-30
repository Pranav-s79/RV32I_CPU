# Instruction Walkthrough

How five instructions travel through the single-cycle datapath in `rtl/rv32i_core.sv`. Signal names match the RTL, so you can find each one in a waveform (`build/sim/core/rv32i_full.vcd`, under `tb_rv32i_core.dut.u_core`).

Encodings come from the GNU assembler (`riscv64-unknown-elf-as -march=rv32i`).

Each instruction completes in one cycle:

```
 rising edge N                                        rising edge N+1
      │  fetch → decode → read regs → execute → memory → choose result  │
      │  (all combinational, settling during the cycle)                 │
      ▼                                                                  ▼
  pc = address of this instruction                PC, rd, memory updated together
```

---

## 1. `add x3, x1, x2`

**Encoding:** `0x002081B3`

```
 funct7   rs2   rs1  funct3  rd   opcode
0000000  00010 00001  000  00011 0110011
```

Assume `x1 = 5`, `x2 = 3`, `pc = 0x100`.

| Step | What happens | Signals |
|------|--------------|---------|
| **Fetch** | The PC register outputs `0x100`. Instruction memory reads word index `0x100 >> 2 = 64` combinationally. | `imem_addr = 0x100`, `instr = 0x002081B3` |
| **Decode** | `instruction_decoder` slices the fields. `control_unit` sees opcode `0110011` (OP) and funct7 = 0, funct3 = 000, so the operation is ADD. | `opcode = 0x33`, `rd = 3`, `rs1 = 1`, `rs2 = 2` |
| **Control** | Write a register, take both ALU operands from registers, use the ALU result. | `reg_write=1`, `alu_a_sel=A_RS1`, `alu_b_sel=B_RS2`, `alu_op=ALU_ADD`, `wb_sel=WB_ALU`, `mem_read=0`, `mem_write=0` |
| **Register read** | Both read ports are combinational. | `rs1_data = 5`, `rs2_data = 3` |
| **ALU** | Operand muxes pass `rs1_data` and `rs2_data`. | `alu_a = 5`, `alu_b = 3`, `alu_result = 8` |
| **Memory** | None. `dmem_addr` still shows `alu_result`, but `dmem_we = 0`, and the loaded word is ignored because `wb_sel ≠ WB_MEM`. | `dmem_we = 0` |
| **PC update** | Not a branch or jump. | `next_pc = pc_plus4 = 0x104` |
| **Writeback** | The writeback mux picks the ALU. | `wb_data = 8` |
| **Clock edge** | No exception, so `commit = 1`: `x3 ← 8`, `pc ← 0x104`. | |

Circuit path: PC flops → IMEM → decoder/control → register file read → ALU adder → writeback mux → register file D input.

---

## 2. `lw x5, 0(x1)`

**Encoding:** `0x0000A283`

```
   imm[11:0]     rs1  funct3  rd   opcode
000000000000   00001  010  00101 0000011
```

Assume `x1 = 0x0001_0000` (start of data memory), and memory word 0 holds `0x8899_AABB`.

| Step | What happens | Signals |
|------|--------------|---------|
| **Fetch** | As before. | `instr = 0x0000A283` |
| **Decode** | Opcode `0000011` = LOAD, funct3 `010` = word. I-type immediate = 0. | `rd = 5`, `rs1 = 1`, `imm = 0` |
| **Control** | Add rs1 + imm to form the address, read memory, write rd with the loaded value. | `reg_write=1`, `mem_read=1`, `alu_b_sel=B_IMM`, `alu_op=ALU_ADD`, `imm_type=IMM_I`, `wb_sel=WB_MEM` |
| **Register read** | | `rs1_data = 0x0001_0000` |
| **ALU** | Computes the byte address. | `alu_result = 0x0001_0000` |
| **Memory** | The SoC address decoder sees `0x0001_0000` inside DMEM (`ram_sel = 1`, `dmem_fault = 0`). Data memory reads word index `addr[11:2] = 0` combinationally. `load_store_unit`: offset = `addr[1:0]` = 0, LW, so no shift and no extension. Alignment is fine. | `dmem_rdata = 0x8899AABB`, `load_data = 0x8899AABB`, `load_misaligned = 0` |
| **PC update** | | `next_pc = pc + 4` |
| **Writeback** | Mux picks load data. | `wb_data = 0x8899AABB` |
| **Clock edge** | `x5 ← 0x8899AABB`, `pc ← pc + 4`. | |

**This is the slowest instruction.** The signal goes PC → instruction memory → decode → register read → ALU adder → address decode and data-memory read → byte shift/extend → writeback mux → register file. That is two memory reads and two adders in series in one cycle, which is why loads set the clock period of a single-cycle CPU.

What if `x1 = 0x0001_0002`? `addr[1:0] = 10` is not word-aligned, so `load_misaligned = 1`. The exception logic picks cause 4, `commit = 0`, and x5 is **not** written (test: `trap_load_misaligned`).

---

## 3. `sw x5, 4(x1)`

**Encoding:** `0x0050A223`

```
imm[11:5]  rs2   rs1  funct3 imm[4:0] opcode
0000000   00101 00001  010   00100   0100011
```

The S-type immediate is split: bits [11:5] sit where funct7 usually is, and bits [4:0] sit where `rd` usually is. `immediate_generator` glues them back together: `imm = {..., instr[31:25], instr[11:7]} = 4`.

Assume `x1 = 0x0001_0000`, `x5 = 0xDEADBEEF`.

| Step | What happens | Signals |
|------|--------------|---------|
| **Decode** | Opcode `0100011` = STORE, funct3 `010` = word. The `rd` field (bits 11:7) holds part of the immediate, not a register, which is why `reg_write` must be 0. | `rs1 = 1`, `rs2 = 5`, `imm = 4` |
| **Control** | | `mem_write=1`, `reg_write=0`, `alu_b_sel=B_IMM`, `imm_type=IMM_S`, `alu_op=ALU_ADD` |
| **Register read** | Both ports used: rs1 for the address, rs2 for the data. | `rs1_data = 0x00010000`, `rs2_data = 0xDEADBEEF` |
| **ALU** | | `alu_result = 0x0001_0004` |
| **Memory** | `load_store_unit`: SW sets all four lanes, data unshifted. Alignment is fine, and the address is in DMEM. | `dmem_wstrb = 4'b1111`, `dmem_wdata = 0xDEADBEEF`, `dmem_we = mem_write && commit = 1` |
| **PC update** | | `next_pc = pc + 4` |
| **Writeback** | None (`reg_write = 0`). | |
| **Clock edge** | Data memory word 1 (`0x0001_0004`) ← `0xDEADBEEF`. `pc ← pc + 4`. | |

For **SB** to `0x0001_0005`, the unit copies the byte into all four lanes (`{4{rs2[7:0]}}`) and sets only `wstrb = 4'b0010`, so only bits [15:8] of the word change. That is little-endian byte placement.

---

## 4. `beq x1, x2, label`

**Encoding** (label = 8 bytes ahead): `0x00208463`

```
imm[12|10:5]  rs2   rs1  funct3 imm[4:1|11] opcode
  0000000    00010 00001  000     01000     1100011
```

The B-type immediate is scrambled so that its bits share positions with the S-type. `immediate_generator` rebuilds `imm = {instr[31], instr[7], instr[30:25], instr[11:8], 0} = 8`. Bit 0 is always 0 because branch targets are multiples of 2.

| Step | What happens | Signals |
|------|--------------|---------|
| **Decode** | Opcode `1100011` = BRANCH, funct3 `000` = BEQ. | `rs1 = 1`, `rs2 = 2`, `imm = 8` |
| **Control** | No register or memory write. | `branch=1`, `imm_type=IMM_B`, `reg_write=0`, `mem_write=0` |
| **Register read** | | `rs1_data`, `rs2_data` |
| **Compare** | `branch_unit` compares directly; the ALU is not used. | `eq = (rs1_data == rs2_data)`, `branch_taken = eq` |
| **Target** | `next_pc_logic` has its own adder. | `pc_rel_target = pc + 8` |
| **PC update** | If taken, `next_pc = pc + 8`; otherwise `pc + 4`. If a taken target is not 4-byte aligned, `target_misaligned = 1` and the branch traps (cause 0). | `next_pc` |
| **Writeback** | None. | |
| **Clock edge** | Only the PC changes. | |

BLT/BGE use a signed compare (`$signed(rs1) < $signed(rs2)`) and BLTU/BGEU an unsigned one. For example, `-1 < 1` is true signed but false unsigned, because `0xFFFFFFFF` is a large unsigned number.

---

## 5. `jal x1, target`

**Encoding** (target = 2048 bytes ahead): `0x001000EF`

```
imm[20|10:1|11|19:12]   rd   opcode
 0 0000000000 1 00000000 00001 1101111
```

`imm = {instr[31], instr[19:12], instr[20], instr[30:21], 0} = 0x800 = 2048`. Range is ±1 MiB.

| Step | What happens | Signals |
|------|--------------|---------|
| **Decode** | Opcode `1101111` = JAL. | `rd = 1`, `imm = 2048` |
| **Control** | Write the return address to rd, always jump. | `jal=1`, `reg_write=1`, `imm_type=IMM_J`, `wb_sel=WB_PC4` |
| **Target** | `next_pc_logic` computes `pc + imm`; JAL always redirects. | `next_pc = pc + 2048` |
| **ALU** | Not needed. | |
| **Writeback** | The return address is the next sequential instruction. | `wb_data = pc_plus4 = pc + 4` |
| **Clock edge** | `x1 ← pc + 4`, `pc ← pc + 2048`, at the same instant. | |

`jal x0, target` (the `j` pseudo-instruction) jumps without saving a link, because writes to x0 are discarded.

**JALR** is similar, but the target is `(rs1 + imm) & ~1`: the ALU adds, and `next_pc_logic` clears bit 0. The link value is computed from the PC, not from rs1, so `jalr t0, 0(t0)` jumps to the OLD t0 and then overwrites t0 (tested in `rv32i_full.S`, test 82).
