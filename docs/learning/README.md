# RV32I CPU Learning Library

This directory teaches the ideas needed to understand, build, verify, and measure
this processor. It starts with digital logic and ends with caches and a final
performance study. Read the lessons in order; each one connects concepts to
files in this repository and ends with questions to check your understanding.

The lessons are companion material, not a substitute for the RISC-V
Unprivileged ISA specification, SystemVerilog language reference, or AMD device
documentation. The core targets RV32I without compressed, floating-point, or
multiplication/division instructions. Privileged architecture is outside the
current core scope.

## Course map

| Lesson | Topic | Prerequisite |
|--------|-------|-------------|
| [01. Digital logic and clocks](01_digital_logic.md) | Bits, Boolean logic, combinational/sequential circuits, reset, timing | None |
| [02. SystemVerilog and synthesis](02_systemverilog.md) | RTL coding rules, simulation versus hardware, common pitfalls | 01 |
| [03. RISC-V and RV32I encoding](03_riscv_isa.md) | Architectural state, instruction formats, signedness, control flow | 01 |
| [04. The single-cycle datapath](04_single_cycle_datapath.md) | Decode, registers, ALU, control, PC, writeback | 02, 03 |
| [05. Memory, loads/stores, and traps](05_memory_and_traps.md) | Byte lanes, alignment, interfaces, exceptions, MMIO | 03, 04 |
| [06. Firmware and the toolchain](06_firmware_toolchain.md) | C/assembly to ELF/hex and startup/linker behavior | 03 |
| [07. Simulation and verification](07_verification.md) | Testbenches, reference models, traces, regressions | 02, 04, 05 |
| [08. FPGA synthesis and timing](08_fpga_timing.md) | LUTs, registers, RAM, constraints, WNS, Fmax | 01, 02, 04 |
| [09. Five-stage pipelining](09_pipeline.md) | Stages, registers, forwarding, stalls, flushes, retirement | 04, 05, 07 |
| [10. Prediction and performance counters](10_prediction_and_counters.md) | BHT/BTB, CPI, throughput, measurement | 09 |
| [11. Formal verification](11_formal.md) | Properties, assumptions, bounded proofs, RVFI | 03, 07, 09 |
| [12. Caches and memory hierarchy](12_caches.md) | Locality, cache arrays, misses, refill, memory latency | 05, 09 |
| [13. Experiments and final evidence](13_final_study.md) | Controlled comparisons, CPI stack, reports, hardware claims | 08-12 |

## How to use the lessons

1. Read the concept and trace it into the linked RTL or documentation.
2. Answer the check questions without looking at the answers in the code.
3. Open the relevant testbench or program and predict what should happen.
4. Run the repository command when you are ready to verify the behavior.
5. Write decisions and your own reflections in the active phase directory.

This is a learning-focused repository. The student implements major CPU blocks;
an agent can explain, review, test, automate, and document them. Use the
current phase checklist to decide what is actually complete. A lesson being
read does not count as implementation or verification evidence.

## Existing project references

- [Project overview and commands](../../README.md)
- [Implemented single-cycle architecture](../architecture.md)
- [Instruction walkthrough](../instruction_walkthrough.md)
- [SystemVerilog guide](../systemverilog_guide.md)
- [Verification strategy and recorded results](../verification.md)
- [Measured Phase 1 baseline](../baseline.md)
- [Phase 2 pipeline proposal](../architecture/pipeline_proposal.md)

## Learning checkpoints

At the end, you should be able to explain:

- how a C instruction becomes bits in instruction memory;
- how the core turns an instruction into register, ALU, memory, and PC actions;
- why a pipeline needs forwarding, interlocks, and flushes;
- how simulation/reference traces establish correctness;
- how to read timing and utilization evidence without overstating it;
- how branch prediction and caches affect CPI, area, and clock frequency.
