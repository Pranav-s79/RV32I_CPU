# RV32I CPU

Pranav Senthilkumar, Sidharth Kanchiraju

Single-cycle RV32I core in SystemVerilog, targeting the Zybo Z7-10 (Zynq XC7Z010).

- ISA: all 37 RV32I base instructions plus FENCE, ECALL, EBREAK. Illegal instructions, misaligned accesses and access faults trap and halt the core (cause codes follow `mcause`). No CSRs yet.
- Memory: 4 KiB instruction ROM at `0x0000_0000`, 4 KiB data RAM at `0x0001_0000`, LED register at `0x8000_0000`. Both memories read combinationally (LUT/LUTRAM, no BRAM).
- Verification: 8 self-checking unit testbenches, plus 11 programs (one compiled from C) traced instruction by instruction against a Python ISS. All pass on Icarus 11 and Vivado 2026.1 xsim.
- Baseline B001 (OOC, 10 ns constraint): 2,054 LUT, 47 FF, 0 latches. WNS −7.194 ns, est. Fmax ≈ 58 MHz, CPI 1. Critical path is the load: ROM → regfile → ALU → data RAM → writeback.

Docs: [architecture](docs/architecture.md), [verification](docs/verification.md), [baseline](docs/baseline.md). Reports in `results/`, baseline records in `configs/baselines/`.

## Build

Simulation runs in WSL (Icarus Verilog, RISC-V GCC). Vivado is called through `cmd.exe`; set its path with `VIVADO` in the `Makefile`.

```bash
make test            # unit tests + all programs vs. reference model (Icarus)
make test-xsim       # same in Vivado xsim
make test-alu        # single bench: test-pc, test-registers, test-imm, test-control,
                     #   test-branch, test-nextpc, test-lsu, test-core
make lint
make programs        # rebuild tests/programs/*.hex (needs RISC-V GCC)
make synth           # Vivado synth + impl -> build/vivado/baseline/summary.txt
make vivado-project  # GUI project in build/vivado/rv32i_phase1/
```

## Layout

```
rtl/          design sources
tb/           testbenches
tests/        test programs (.S, linker script, .hex images)
software/     C programs for the core
scripts/      test runner, Python ISS, Vivado Tcl
constraints/  .xdc
configs/      baseline records
results/      saved simulation, synthesis and timing reports
docs/         design documentation
```

## Roadmap

1. Single-cycle RV32I (done)
2. Broader software tests
3. 5-stage pipeline, BRAM memories
4. Hazard detection and forwarding
5. Compliance tests (riscv-arch-test), Zicsr
6. Board bring-up and FPGA characterization
7. Performance and area optimization
