# Phase 1 Learning Log

Items marked *(student)* are for the student to write in their own words. Agents must not fill them in.

## Concepts I understand

- *(student)*

## Concepts I am still learning

- *(student)*

## Things I personally implemented

- First drafts of `program_counter.sv` (PC register, reset to 0, +4 each cycle) and `instruction_memory.sv` (hard-coded case ROM). Preserved in `docs/phase_1/student_drafts/`.
- *(student: add anything else)*

## Things agents/tools assisted with

- Claude (2026-10-29, at the student's request) wrote all Phase 1 RTL, extending the student's two drafts; all testbenches; the test programs; the Python reference model; the Makefile and scripts; the Vivado Tcl; and the Phase 1 docs.
- GCC/binutils assembled and compiled the test programs.
- Vivado 2026.1 synthesized and implemented the design and produced the baseline reports.

## Suggested study order (component walkthrough)

1. `program_counter.sv`: compare with your draft; what `enable` and `next_pc` add
2. `instruction_memory.sv`: compare with your draft; why a combinational read
3. `instruction_decoder.sv` + `immediate_generator.sv`: instruction formats
4. `register_file.sv`: 2 read ports, 1 write port, x0
5. `alu.sv`: signed vs. unsigned, shifts
6. `control_unit.sv`: the truth table; illegal detection
7. `branch_unit.sv` + `next_pc_logic.sv`: control flow
8. `load_store_unit.sv` + `data_memory.sv`: byte lanes
9. `rv32i_core.sv`: putting it together; exceptions and `commit`
10. `rv32i_soc_top.sv`: memory map
11. Waveform of `c_simple` alongside `build/programs/c_simple.dump`

## Commands worth remembering

```bash
make test                 # everything (Icarus)
make test-alu             # one unit test
make test-core            # programs vs. reference model
make test-xsim            # same in Vivado xsim
make programs             # rebuild program images
make synth                # Vivado baseline (~10 min)
make vivado-project       # GUI project in build/vivado/rv32i_phase1/
python3 scripts/rv32i_iss.py tests/programs/c_simple.hex /dev/stdout   # run the model alone
```

## Questions to revisit

- Why does a load set the clock period? Trace the path in `results/timing/phase1_soc_route_timing_paths.rpt`.
- Why is 79 % of the critical-path delay routing rather than logic?
- What would break if the register file had a synchronous read?
- *(student)*

## Phase reflection

*(student: write this after you can explain every module)*
