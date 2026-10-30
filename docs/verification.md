# Verification (Phase 1)

## Strategy

Three layers, each catching different bugs:

1. **Unit testbenches** (`tb/tb_*.sv`): one per block, self-checking. Expected values come from hand-computed corner cases, assembler-produced encodings, and reference functions written differently from the RTL.
2. **Program tests** (`tests/programs/*.S`): real RV32I programs run on the whole system (`rv32i_soc_top`). The main program checks its own results and reports pass/fail in `a0`.
3. **Reference-model comparison** (`scripts/rv32i_iss.py`): an independent Python instruction-set simulator runs the same program. Every retired instruction (PC, instruction, register write, memory write) and the final state must match the RTL **line for line**.

On top of that:

- **Second simulator:** the whole suite also runs in Vivado's simulator (xsim), to rule out Icarus-specific behavior.
- **Fault injection:** bugs were planted in copies of the RTL to show the tests catch them (see below).

## How to run

```bash
make test           # unit tests + all programs vs. reference model (Icarus)
make test-unit      # unit tests only
make test-alu       # one unit test: test-pc, test-registers, test-alu, test-imm,
                    #   test-control, test-branch, test-nextpc, test-lsu
make test-core      # all programs vs. reference model
make test-xsim      # the same unit tests + programs in Vivado xsim (needs make test-core first)
make lint           # Icarus -Wall elaboration (+ Verilator if installed)
make programs       # rebuild tests/programs/*.hex from source (needs RISC-V GCC)
```

Every test prints `PASS: ...` or `FAIL: ...` and exits non-zero on failure.

## Unit testbenches

| Testbench | Checks | What it covers |
|-----------|-------:|----------------|
| `tb_program_counter` | 9 | reset value (non-zero `RESET_VECTOR`), update on enable, hold when disabled, reset priority over enable, updates only at the clock edge |
| `tb_register_file` | 2,102 | power-up zeros; every register on both ports; x0 ignores writes (port and storage); `we = 0`; read-during-write (old value before the edge, new after); 1,000 random operations vs. an array model |
| `tb_alu` | 5,025 | 25 hand-computed corner cases (overflow, wrap, shift by 0/31/33, sign fill, signed vs. unsigned compares); 5,000 random vectors vs. a reference using different math (bit-level signed compare, 64-bit SRA, `x + ~y + 1` for SUB) |
| `tb_immediate_generator` | 10,020 | 20 assembler-encoded instructions incl. min/max offsets for every format; 10,000 random immediates packed by an independent encoder |
| `tb_control_unit` | ~15,650* | every RV32I instruction (assembler encodings) → control signals; FENCE/FENCE.TSO legal; ECALL/EBREAK exact; 29 illegal encodings (M/A/F/C extensions, RV64 forms, reserved funct3/funct7, FENCE.I, CSR, MRET, WFI, malformed ECALL); sweep of all 128 opcodes, checking that illegal never changes state |
| `tb_branch_unit` | 3,020 | all 6 conditions taken and not taken; signed/unsigned edge cases; `branch = 0`; reserved funct3; 3,000 random vs. a sign-flip reference |
| `tb_next_pc_logic` | 38 | sequential; branch forward/back; JAL; JALR with bit-0 clearing; misaligned targets (+2, +6, bit 1 set); not-taken branches never trap; PC wrap |
| `tb_load_store_unit` | 101 | LB/LBU/LH/LHU/LW at every byte offset with sign-revealing data; positive values; SB/SH/SW strobes and lane data at every offset; every misaligned case; idle state |

\* The opcode sweep uses random fill bits, so the exact count varies slightly between simulators.

## Program tests

| Program | What it checks | Expected end |
|---------|----------------|--------------|
| `rv32i_full` | All 37 RV32I computational/memory/control instructions + FENCE: overflow, shifts by 0/31/35, signed vs. unsigned, `sltiu -1`, x0 writes (incl. load to x0), every load width and offset, byte/halfword stores, negative offsets, last DMEM word, LED register, every branch taken and not taken, a backward loop, JAL link, JALR bit-0 clear, JALR with rd = rs1, JALR negative offset, call/ret, `j` doesn't link | ECALL, a0 = 0, LED = 0101 |
| `c_simple` | `software/simple.c` compiled with GCC `-O0` + `crt0.S`: stack, function call, return | ECALL, a0 = 8 |
| `trap_illegal` | `mul` (M extension) is illegal; earlier instructions committed; trapping one did not | cause 2, tval = `0x02C585B3` |
| `trap_ebreak` | EBREAK halts | cause 3, tval = PC |
| `trap_load_misaligned` | `lw` at +2; rd not written | cause 4, tval = `0x10002` |
| `trap_store_misaligned` | `sh` at odd address; memory unchanged | cause 6, tval = `0x10005` |
| `trap_load_fault` | load from IMEM range (not on data bus) | cause 5, tval = `0x100` |
| `trap_store_fault` | store to `0x11000`, one past DMEM; no wrap-around to `0x10000` | cause 7, tval = `0x11000` |
| `trap_jalr_misaligned` | JALR target with bit 1 set; ra not written | cause 0, tval = target |
| `trap_branch_misaligned` | not-taken branch with offset +2 does **not** trap; taken one does | cause 0, tval = PC + 2 |
| `trap_fetch_fault` | jump to `0x1000` (past IMEM) succeeds; the fetch there faults | cause 1, PC = tval = `0x1000` |

Each program is checked three ways: the testbench's own checks (halt, cause, a0, clean re-reset), line-by-line trace equality with the Python model, and the hand-written expectations in `scripts/run_core_tests.py` (trap PC from the symbol table, tval, specific registers and memory words).

## Results (2026-10-29)

Icarus Verilog 11.0:

```
PASS: tb_program_counter (9 checks)
PASS: tb_register_file (2102 checks)
PASS: tb_alu (5025 checks)
PASS: tb_immediate_generator (10020 checks)
PASS: tb_control_unit (15656 checks)
PASS: tb_branch_unit (3020 checks)
PASS: tb_next_pc_logic (38 checks)
PASS: tb_load_store_unit (101 checks)
PASS: rv32i_full                397 instructions retired, trap cause=11 pc=0x000005f4 tval=0x00000000
PASS: c_simple                   27 instructions retired, trap cause=11 pc=0x00000008 tval=0x00000000
PASS: trap_illegal                3 instructions retired, trap cause= 2 pc=0x0000000c tval=0x02c585b3
PASS: trap_ebreak                 1 instructions retired, trap cause= 3 pc=0x00000004 tval=0x00000004
PASS: trap_load_misaligned        2 instructions retired, trap cause= 4 pc=0x00000008 tval=0x00010002
PASS: trap_store_misaligned       5 instructions retired, trap cause= 6 pc=0x00000014 tval=0x00010005
PASS: trap_load_fault             2 instructions retired, trap cause= 5 pc=0x00000008 tval=0x00000100
PASS: trap_store_fault            7 instructions retired, trap cause= 7 pc=0x0000001c tval=0x00011000
PASS: trap_jalr_misaligned        3 instructions retired, trap cause= 0 pc=0x0000000c tval=0x00000012
PASS: trap_branch_misaligned      3 instructions retired, trap cause= 0 pc=0x0000000c tval=0x0000000e
PASS: trap_fetch_fault            2 instructions retired, trap cause= 1 pc=0x00001000 tval=0x00001000
==== CORE TESTS: all 11 programs PASSED (RTL matches reference model) ====
```

Vivado 2026.1 xsim: all 8 unit testbenches and all 11 programs pass (traces identical to the model). A saved copy of the full output is in `results/simulation/phase1_test_results.txt`.

## Fault-injection check

To show the tests can fail, these bugs were planted one at a time in a scratch copy of the RTL, and the program suite was re-run:

| Planted bug | Caught by |
|-------------|-----------|
| SRA does a logical shift | `rv32i_full` |
| SLT compares unsigned | `rv32i_full` |
| LB zero-extends | `rv32i_full` |
| BGE compares unsigned | `rv32i_full` |
| JALR doesn't clear bit 0 | `rv32i_full` |
| Link address = PC + 8 | all 11 programs |
| FENCE decoded as illegal | `rv32i_full` |
| Store not cancelled by an exception | `trap_store_misaligned` |
| Register write not cancelled by an exception | `trap_load_misaligned`, `trap_load_fault`, `trap_jalr_misaligned` |
| S-type immediate decoded as I-type | `rv32i_full`, `c_simple`, 2 trap tests |
| DMEM end-of-range check removed (aliasing) | `rv32i_full`, `trap_store_fault` |
| SH always writes the low lanes | `rv32i_full` |
| x0 read **and** write protection removed | `rv32i_full` |
| x0 **write** protection removed (read mux kept) | not visible to programs (the read mux hides it); caught by the white-box check added to `tb_register_file` |

14 of 14 caught.

## Reading the waveforms

Program tests dump VCD files to `build/sim/core/<program>.vcd` for `rv32i_full`, `c_simple`, and `trap_load_misaligned`. Unit tests dump to `build/sim/tb_*.vcd`. Copies of two are saved in `results/simulation/waveforms/`.

GTKWave is not installed. To view them: `sudo apt install gtkwave`, then `gtkwave build/sim/core/rv32i_full.vcd`. In Vivado you can instead run the testbench in the GUI project (see the README).

Useful signals (under `tb_rv32i_core.dut.u_core`):

| Signal | What to look for |
|--------|------------------|
| `clk`, `reset` | one instruction per clock cycle after reset falls |
| `pc`, `instr` | the program stepping through memory; jumps show as non-+4 changes |
| `opcode`, `rd`, `rs1`, `rs2`, `imm` | decoded fields |
| `alu_op`, `alu_a`, `alu_b`, `alu_result` | the ALU at work |
| `reg_write`, `wb_sel`, `wb_data` | what gets written to `rd` at the next edge |
| `dmem_addr`, `dmem_we`, `dmem_wstrb`, `dmem_wdata`, `dmem_rdata` | memory traffic and byte lanes |
| `branch_taken`, `next_pc` | control flow decisions |
| `exception`, `commit`, `halted`, `trap_cause` | the trap path; `commit` drops to 0 for the trapping instruction |

Tip: everything combinational settles during the cycle; values are "real" just before the rising edge.

## Known gaps

- No official compliance suite yet (`riscv-tests` / `riscv-arch-test`). Planned for Phase 5.
- The reference model was written by the same author (Claude) as the RTL. It shares no code or structure, and it agrees with hand-computed expectations, but it is not a third-party model like Spike or Sail.
- No random instruction generator (constrained-random programs). The program tests are directed.
- No formal verification.
- Programs are small (≤ 400 instructions); no long-running software.
- Timing is not simulated (zero-delay RTL simulation). Timing is checked only by Vivado static timing analysis.
- Not tested on the physical board.
