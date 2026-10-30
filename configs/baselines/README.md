# Baselines

A baseline is a recorded, reproducible reference point that later changes are compared against. No baselines exist yet; the first is expected in Phase 6 (FPGA characterization of the single-cycle design).

## What each baseline records

| Field | Example |
|-------|---------|
| **Design version** | Git commit hash and/or tag |
| **Configuration** | Single-cycle vs. pipelined, memory sizes, parameters |
| **Target FPGA** | Zynq XC7Z010 (part `xc7z010clg400-1`), Zybo Z7-10 |
| **Clock constraints** | Constraint file and target period (e.g. 10 ns / 100 MHz) |
| **Synthesis settings** | Vivado version, synthesis/implementation strategy, key options |
| **Test version** | Which tests/programs were run, and their pass/fail result |
| **Measured results** | Fmax, WNS, LUTs, FFs, BRAM, CPI, with links to reports in `results/` |

## Why

Performance comparisons only mean something when both sides are measured the same way. If the constraint, Vivado version, or strategy differs between "before" and "after", the comparison is invalid. Recording every field makes each result reproducible.

## Naming

One file per baseline, e.g. `B001_single_cycle.md`. Experiments in `docs/phase_N/experiments.md` reference baselines by ID.
