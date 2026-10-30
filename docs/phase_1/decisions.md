# Phase 1 Decisions

## D-101: Claude implements the Phase 1 RTL

- **Decision:** At the student's explicit request (2026-10-29), Claude wrote the Phase 1 RTL, testbenches, reference model, and scripts, then explains the design component by component.
- **Reason:** The student asked for a complete, verified Phase 1 and a guided walkthrough of the real code.
- **Consequences:** Overrides the default student-ownership rule (`CLAUDE.md`, `AGENTS.md`) for this phase only. The student's drafts are preserved in `docs/phase_1/student_drafts/`. Authorship must be stated accurately (see `docs/phase1_interview_guide.md`). Later phases go back to the default rule unless the student says otherwise.

## D-102: Use Vivado 2026.1

- **Decision:** Use the Vivado 2026.1 install (`C:\AMDDesignTools\2026.1`).
- **Reason:** The 2023.1 install (`C:\Xilinx\Vivado\2023.1`) does not start in batch mode from WSL (it only prints "ECHO is off."). 2026.1 runs synthesis, implementation, and xsim.
- **Consequences:** All baselines must use 2026.1 or record the change of tool version (results are not comparable across versions).

## D-103: Asynchronous-read memories in Phase 1

- **Decision:** Instruction and data memories have combinational reads (LUT ROM / distributed RAM), 4 KiB each.
- **Reason:** A single-cycle datapath needs fetch and load data in the same cycle; block RAM reads are registered.
- **Consequences:** Memories are small and on the critical path. Moving to BRAM is planned with the pipeline (Phase 3).

## D-104: Memories outside the core; SoC owns the memory map

- **Decision:** `rv32i_core` exposes fetch and data ports; `rv32i_soc_top` holds memories, the LED register, and address decoding.
- **Reason:** The core can be synthesized and measured alone; memory map changes don't touch the core.
- **Consequences:** Unmapped addresses are signaled to the core with `imem_fault`/`dmem_fault`.

## D-105: Exceptions halt the core

- **Decision:** No CSRs. Any exception (illegal instruction, ECALL, EBREAK, misaligned target/access, access fault) stops the core before the instruction commits, and holds `trap_cause` (mcause numbering), `trap_pc`, and `trap_tval` until reset.
- **Reason:** RV32I base has no CSRs; the task forbids silently treating ECALL/EBREAK/illegal encodings as NOPs.
- **Consequences:** Not full privileged-spec compliance; no trap handlers. Zicsr + machine-mode traps can be added later (Phase 5).

## D-106: Misaligned loads/stores trap; FENCE is a no-op; FENCE.I is illegal

- **Decision:** Misaligned accesses raise cause 4/6. FENCE (any fm/pred/succ, funct3 = 000) has no effect. FENCE.I and CSR instructions are illegal.
- **Reason:** All allowed by the spec for a single in-order hart without caches; simplest correct behavior.
- **Consequences:** Software must keep data aligned.

## D-107: Separate branch comparator and target adder

- **Decision:** `branch_unit` compares rs1/rs2 directly; `next_pc_logic` has its own `pc + imm` adder. The ALU is used only for JALR's `rs1 + imm` target.
- **Reason:** Keeps the ALU simple and the branch decision independent of ALU operand muxing.
- **Consequences:** One extra 32-bit adder (~8 CARRY4).

## D-108: Baseline method

- **Decision:** Out-of-context implementation of `rv32i_soc_top` at a fixed 10 ns reference period; Fmax estimated as 1/(T − WNS). Core-only synthesis for resource usage. ROM image `rv32i_full.hex`.
- **Reason:** Reproducible, comparable across phases, and measures register-to-register paths without board I/O.
- **Consequences:** The ideal-clock assumption (no HD.CLK_SRC) and missing I/O timing must be noted. A period sweep in Phase 6 can refine the estimate.
