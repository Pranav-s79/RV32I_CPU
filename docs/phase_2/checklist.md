# Phase 2 Checklist

Items are checked only when code or saved run output provides evidence.

## Design decisions

- [ ] Choose branch/jump resolution stage and document its redirect timing.
- [ ] Choose how the pipeline interacts with instruction and data memory latency.
- [ ] Define retirement/commit trace fields shared with the Phase 1 comparison flow.
- [ ] Keep Phase 1 baseline sources and B001 evidence unchanged.

## Implementation

- [ ] Add IF/ID, ID/EX, EX/MEM, and MEM/WB state with valid bits.
- [ ] Carry PC, instruction, operands, destination, and required controls through the stages.
- [ ] Add EX/MEM and MEM/WB forwarding, with newest producer taking priority.
- [ ] Add a load-use interlock that holds PC and IF/ID and injects one bubble.
- [ ] Add redirect and flush behavior for branches and jumps.
- [ ] Prove invalid/flushed entries cannot write registers or memory.
- [ ] Preserve correct x0 behavior and reset behavior.

## Verification and evidence

- [ ] Compare single-cycle and pipelined retirement streams on the same programs.
- [ ] Cover forwarding priority, load-use, branch-after-load, back-to-back redirects, and wrong-path stores.
- [ ] Run existing unit and program regressions against the affected design.
- [ ] Save the exact command, tool versions, and pass summary.
- [ ] Save Vivado utilization and timing reports under `results/`.
- [ ] Record Fmax, WNS, LUTs, FFs, BRAM, CPI, stalls, and flushes with their run configuration.
- [ ] Student review and reflection completed.
