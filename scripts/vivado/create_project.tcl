# create_project.tcl
# Creates a Vivado GUI project for exploring the Phase 1 design:
# schematic view, synthesis, timing reports, and behavioral simulation.
#
#   make vivado-project          (from WSL)
#   or in the Vivado Tcl console: cd C:/Users/prana/RV32i_cpu; source scripts/vivado/create_project.tcl
#
# Then open build/vivado/rv32i_phase1/rv32i_phase1.xpr in Vivado.
# The project references the repository's source files (it does not copy them),
# so edits in VS Code show up in Vivado.

set root [file normalize [file join [file dirname [info script]] .. ..]]
set proj_dir $root/build/vivado/rv32i_phase1

create_project rv32i_phase1 $proj_dir -part xc7z010clg400-1 -force

set rtl {rv32i_pkg program_counter instruction_memory instruction_decoder control_unit
         immediate_generator register_file alu branch_unit next_pc_logic load_store_unit
         data_memory rv32i_core rv32i_soc_top}
foreach m $rtl {
    add_files -norecurse -fileset sources_1 $root/rtl/$m.sv
}
set_property file_type SystemVerilog [get_files -of_objects [get_filesets sources_1]]
set_property top rv32i_soc_top [get_filesets sources_1]

# Program image for the instruction ROM (same as the baseline).
set hex $root/tests/programs/rv32i_full.hex
set_property generic "IMEM_INIT=\"$hex\"" [get_filesets sources_1]

# Timing constraint (same as the baseline). The design is synthesized
# out-of-context because it has no board pin constraints yet.
add_files -fileset constrs_1 $root/constraints/timing_phase1.xdc
set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-mode out_of_context} -objects [get_runs synth_1]

# Simulation: full-system testbench running rv32i_full.
foreach tb {tb_rv32i_core tb_alu tb_register_file tb_program_counter tb_immediate_generator
            tb_control_unit tb_branch_unit tb_next_pc_logic tb_load_store_unit} {
    add_files -norecurse -fileset sim_1 $root/tb/$tb.sv
}
add_files -norecurse -fileset sim_1 $root/tb/tb_check.svh
set_property file_type SystemVerilog [get_files -of_objects [get_filesets sim_1] *.sv]
set_property include_dirs [list $root/tb] [get_filesets sim_1]
set_property top tb_rv32i_core [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
file mkdir $proj_dir/sim_out
set_property -name {xsim.simulate.xsim.more_options} \
    -value "-testplusarg PROGRAM=$hex -testplusarg TRACE=$proj_dir/sim_out/rv32i_full.trace.txt" \
    -objects [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_1]

puts "Created $proj_dir/rv32i_phase1.xpr"
