# Phase 0 Decisions

Format: **Decision**, **Reason**, **Consequences**. Add new decisions at the bottom; do not rewrite old ones. If a decision changes, add a new entry that supersedes it.

---

## D-001: Use RV32I as the base ISA

- **Decision:** Implement the RV32I base integer instruction set.
- **Reason:** Small enough to learn clearly (about 40 instructions) while still being a real, standard RISC-V architecture that GCC can target.
- **Consequences:** No multiply/divide (M), atomics (A), floating point (F/D), or compressed instructions (C). Software must be compiled with `-march=rv32i -mabi=ilp32`. Extensions can be added later as separate experiments.

## D-002: Use SystemVerilog

- **Decision:** Write RTL and testbenches in SystemVerilog.
- **Reason:** Modern RTL language with clearer constructs (`logic`, `always_comb`, `always_ff`, enums, packages) and good support in Vivado.
- **Consequences:** Icarus Verilog has only partial SystemVerilog support (compile with `-g2012`). Some constructs may need to stay simple or be checked in Vivado's simulator.

## D-003: Use Vivado for FPGA implementation

- **Decision:** Use AMD Vivado (Windows) for synthesis, implementation, timing, and bitstream generation.
- **Reason:** Required toolchain for the Zynq XC7Z010 on the Zybo Z7-10.
- **Consequences:** Synthesis/timing runs happen on Windows, not WSL. Only selected reports are copied into `results/`. Which installed version is used (2023.1 or 2026.1) is still to be decided and recorded.

## D-004: Use WSL Ubuntu for RISC-V software tooling and automation

- **Decision:** Run RISC-V GCC/binutils, Icarus Verilog, and helper scripts in WSL2 Ubuntu 22.04.
- **Reason:** These tools are easiest to install and script on Linux.
- **Consequences:** Two environments (WSL and Windows) must agree on file paths. The repo lives on the Windows filesystem (`/mnt/c/...`) so Vivado can reach it, which makes WSL file access slower.

## D-005: Build a single-cycle CPU before a pipeline

- **Decision:** Phase 1 builds a single-cycle RV32I CPU; pipelining comes in Phase 3.
- **Reason:** A single-cycle design is the simplest correct implementation. It provides a correctness baseline and a performance baseline (Fmax, area, CPI = 1) for the pipeline to be compared against.
- **Consequences:** The single-cycle design will have a low Fmax. That is expected and is the point of the comparison.

## D-006: Measure before optimizing

- **Decision:** Every optimization starts from a recorded baseline and is written up as an experiment.
- **Reason:** Claims like "faster" or "smaller" must be backed by measurements taken under the same conditions.
- **Consequences:** Extra work per optimization (baseline record, experiment write-up), but results are reproducible and credible.

## D-007: Physical Zybo validation may be deferred

- **Decision:** Running on the physical Zybo Z7-10 can be deferred until the hardware is available.
- **Reason:** Simulation, synthesis, and timing analysis can all be done without the board.
- **Consequences:** Until tested on hardware, results are "post-implementation" numbers only. Docs must not claim the design was run on hardware until it has been.
