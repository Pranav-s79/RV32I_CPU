# Phase 2: Five-Stage Pipeline

## Goal

Build a five-stage RV32I implementation that preserves the architectural behavior of the Phase 1 single-cycle core while improving the clock-frequency limit. The single-cycle implementation and its B001 reports remain the reference baseline.

This phase follows Phase 2 of the supplied *RV32I Processor Design: Complete Project Guide*. It includes the initial pipeline hazard controls so that the pipeline can execute dependent instruction streams correctly. Predictor, cache, formal, and CPI-study work remains in later milestones.

## Concepts

- Pipeline throughput versus latency
- IF, ID, EX, MEM, and WB stage boundaries
- Carrying control and instruction-valid state with each pipeline entry
- EX/MEM and MEM/WB data forwarding, and forwarding priority
- Load-use interlocks and bubbles
- Branch/jump redirect and wrong-path flush
- Architectural retirement comparison independent of cycle count

## Student implementation

The student owns all major pipeline RTL. Start from the existing `rtl/rv32i_core.sv` and `rtl/rv32i_soc_top.sv`, keeping Phase 1 available as the golden core. Do not convert or replace the current baseline in place.

Suggested initial module boundaries:

| Area | Responsibility |
|------|----------------|
| Pipeline core | PC selection, stage registers, commit/retirement visibility |
| Hazard unit | Load-use detection, PC/IF-ID hold, ID/EX bubble, redirect flush |
| Forwarding unit | Select newest available producer for each EX source |
| Stage records | Carry valid, PC, instruction, operands, destination, and controls |

The exact module split and branch-resolution stage remain student decisions recorded in `decisions.md` before RTL changes.

## Agent assistance

Codex may review the pipeline specification and student RTL, explain hazards and waveforms, help extend the verification harness, and document measurements. Repository policy reserves major CPU blocks for the student to implement.

## Verification

Use the same assembly programs on the single-cycle and pipelined cores. Compare retirement order and architectural effects while ignoring cycle numbers. Include dependencies that exercise EX/MEM and MEM/WB forwarding, repeated writes to one destination, load-use stalls, taken and untaken branches, jumps, and wrong-path stores. A killed instruction must never write a register or memory.

Preserve the Phase 1 test results; a passing final-state check by itself is not sufficient evidence of architectural equivalence.

## Measurements

Record pipeline Fmax, WNS, LUTs, FFs, BRAM, CPI, stall cycles, and flush cycles using the same FPGA part, Vivado version, clock constraint, and implementation method as B001 wherever those comparisons are available. Report `Fmax / CPI` for throughput context. Do not enter numbers until the corresponding run produces evidence.

## Exit criteria

See [checklist.md](checklist.md). The phase is not complete until the pipeline passes the architectural comparison, hazards and wrong-path side effects are covered, and reproducible timing/resource results are saved.

## Reflection

The student completes [learning_log.md](learning_log.md) in their own words.

## Milestone

No Phase 2 implementation or milestone commit exists yet.
