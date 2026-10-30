# Results

Selected, intentionally saved evidence from simulation and Vivado runs. This is **not** a dump of tool output.

| Directory | Contents |
|-----------|----------|
| `simulation/` | Selected simulation summaries or logs (pass/fail runs, CPI counts) |
| `synthesis/` | Selected synthesis/utilization summaries (LUTs, FFs, BRAM) |
| `timing/` | Selected timing summaries (WNS, critical path, Fmax) |

## Policy

- **Do not commit generated Vivado project directories** (`*.runs/`, `*.cache/`, `.Xil/`, `*.sim/`, checkpoints). They are large and can be regenerated. `.gitignore` already excludes them.
- Keep only useful summaries and intentionally selected reports (e.g. output of `report_utilization`, `report_timing_summary`).
- Name files so they can be traced to a design version, e.g. `timing/2026-11-15_single_cycle_a1b2c3d_100MHz.rpt`.
- Every number quoted in the docs should link to a file here.
- Never edit a saved report by hand. If a result is wrong, re-run and save a new one.
