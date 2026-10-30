# Phase 1 Checklist

Checked items have evidence (command output saved in `results/` or files in the repo).

## Completion criteria

- [x] Required synthesizable RTL modules exist (`rtl/`, 14 files)
- [x] Core modules integrate correctly (`rv32i_soc_top` elaborates, simulates, synthesizes, and routes)
- [x] Required RV32I instruction behavior tested (`rv32i_full.S` + unit tests)
- [x] x0, reset, sign extension, and branch behavior correct (unit + program tests)
- [x] Directed unit tests pass (8/8, Icarus and xsim)
- [x] Integrated test program passes (11/11 programs; traces match the reference model)
- [x] Lint/elaboration succeeds with available tools (Icarus `-Wall` clean; Verilator not installed)
- [x] No unintended latches (Vivado `all_latches` = 0 for SoC and core)
- [x] Vivado synthesis scripts prepared (`scripts/vivado/synth_baseline.tcl`, `create_project.tcl`)
- [x] Synthesis and timing executed (Vivado 2026.1, post-route)
- [x] Actual measurements documented (`docs/baseline.md`, `configs/baselines/B001_single_cycle.md`)
- [x] Architecture and learning documentation complete (`docs/*.md`)
- [x] Unsupported features and verification gaps listed (`docs/architecture.md` §9, `docs/verification.md`)

## Still open

- [ ] Student review: read every RTL file and explain it without notes
- [ ] Student reflection in `learning_log.md`
- [ ] Phase 1 milestone commit (and record its hash in B001)
- [ ] Optional: install Verilator and run `make lint` again
- [ ] Optional: install GTKWave and inspect `results/simulation/waveforms/*.vcd`
