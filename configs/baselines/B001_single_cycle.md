# B001: Single-cycle RV32I (Phase 1)

| Field | Value |
|-------|-------|
| **Baseline ID** | B001 |
| **Date measured** | 2026-10-29 |
| **Design version** | Uncommitted working tree on top of commit `8cdcd1f`. RTL file hashes in [`B001_rtl_sha256.txt`](B001_rtl_sha256.txt). Replace with the Phase 1 milestone commit hash once committed. |
| **Configuration** | Single-cycle; 4 KiB instruction ROM + 4 KiB data RAM, both asynchronous read (LUT-based); reset vector `0x0`; trap = halt; no CSRs |
| **Top modules measured** | `rv32i_soc_top` (implemented), `rv32i_core` (synthesized) |
| **Target FPGA** | Zynq-7000 `xc7z010clg400-1` (Zybo Z7-10) |
| **Clock constraint** | `constraints/timing_phase1.xdc`: `create_clock -period 10.000 [get_ports clk]` |
| **Tool / settings** | Vivado 2026.1, non-project batch, `synth_design -mode out_of_context`, default directives for synth/opt/place/route, no phys_opt |
| **Script** | `scripts/vivado/synth_baseline.tcl` (`make synth`) |
| **ROM contents** | `tests/programs/rv32i_full.hex` |
| **Test version** | `make test`: 8/8 unit testbenches and 11/11 programs pass in Icarus 11.0 and Vivado 2026.1 xsim (same working tree) |

## Measured results

| Metric | `rv32i_soc_top` post-route | `rv32i_core` post-synth |
|--------|---------------------------:|------------------------:|
| WNS @ 10 ns | −7.194 ns | not measured (core alone has no memory paths) |
| Estimated Fmax = 1000/(10 − WNS) | ≈ 58.2 MHz | – |
| Critical path | `pc_reg[6]` → IMEM → regfile → ALU → DMEM → writeback → regfile DI, 16.925 ns, 19 levels | – |
| WHS | +0.257 ns | – |
| LUTs | 2,054 | 1,079 |
| LUT as distributed RAM | 556 | 48 |
| FFs | 47 | 101 |
| Latches | 0 | 0 |
| CARRY4 | 51 | 51 |
| BRAM | 0 | 0 |
| DSP | 0 | 0 |
| CPI | 1 (by design: no stall path; one retirement per committing cycle) | |

## Source reports

- `results/timing/phase1_baseline_summary.txt`
- `results/timing/phase1_soc_route_timing_summary.rpt`
- `results/timing/phase1_soc_route_timing_paths.rpt`
- `results/timing/phase1_soc_route_logic_levels.rpt`
- `results/timing/phase1_soc_synth_timing_summary.rpt`
- `results/synthesis/phase1_soc_route_utilization.rpt`, `phase1_soc_route_utilization_hier.rpt`
- `results/synthesis/phase1_core_synth_utilization.rpt`, `phase1_core_synth_utilization_hier.rpt`
