# synth_baseline.tcl
# Reproducible Phase 1 baseline (Vivado non-project batch mode).
#
#   Run 1: rv32i_soc_top (core + instruction ROM + data RAM + LED register)
#          synth -> opt -> place -> route, default strategies, OOC
#          Gives the real single-cycle critical path (through the memories).
#   Run 2: rv32i_core alone, synthesis only, OOC
#          Gives the core's own resource usage without the memories.
#
# Run from the repository root:
#   make synth
# Outputs: build/vivado/baseline/*.rpt (full reports), summary.txt

set root [file normalize [file join [file dirname [info script]] .. ..]]
cd $root
set part xc7z010clg400-1
set out  build/vivado/baseline
file mkdir $out

set rtl {rv32i_pkg program_counter instruction_memory instruction_decoder control_unit
         immediate_generator register_file alu branch_unit next_pc_logic load_store_unit
         data_memory rv32i_core rv32i_soc_top}
foreach m $rtl { read_verilog -sv rtl/$m.sv }
read_xdc constraints/timing_phase1.xdc

# Instruction ROM contents. The ROM is built from LUTs and Vivado optimizes
# it for its contents, so the program image is part of the baseline config.
set hex [file normalize tests/programs/rv32i_full.hex]

set summary [open $out/summary.txt w]
proc note {fh msg} { puts $fh $msg; puts $msg }

note $summary "Phase 1 baseline - [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"
note $summary "Vivado: [version -short]   Part: $part"
set xdc [open constraints/timing_phase1.xdc]
foreach line [split [read $xdc] "\n"] {
    if {[string match "create_clock*" $line]} { note $summary "Clock constraint: $line" }
}
close $xdc
note $summary "IMEM image: tests/programs/rv32i_full.hex"
note $summary ""

proc path_summary {fh label} {
    set p [lindex [get_timing_paths -setup -max_paths 1 -nworst 1] 0]
    note $fh "$label worst setup path:"
    note $fh "  slack (WNS)     : [get_property SLACK $p] ns"
    note $fh "  requirement     : [get_property REQUIREMENT $p] ns"
    note $fh "  datapath delay  : [get_property DATAPATH_DELAY $p] ns"
    note $fh "  logic levels    : [get_property LOGIC_LEVELS $p]"
    note $fh "  startpoint      : [get_property STARTPOINT_PIN $p]"
    note $fh "  endpoint        : [get_property ENDPOINT_PIN $p]"
    set wns [get_property SLACK $p]
    set per [get_property REQUIREMENT $p]
    note $fh "  est. Fmax       : [format %.2f [expr {1000.0 / ($per - $wns)}]] MHz  (= 1000 / (period - WNS))"
}

# ---------------- Run 1: full SoC, implemented ----------------
synth_design -top rv32i_soc_top -part $part -mode out_of_context \
             -generic "IMEM_INIT=\"$hex\""
note $summary "Latches after synthesis (SoC): [llength [all_latches]]"
report_utilization              -file $out/soc_synth_utilization.rpt
report_timing_summary           -file $out/soc_synth_timing_summary.rpt
path_summary $summary "SoC post-synthesis"

opt_design
place_design
route_design
write_checkpoint -force $out/soc_routed.dcp

report_utilization                   -file $out/soc_route_utilization.rpt
report_utilization -hierarchical     -file $out/soc_route_utilization_hier.rpt
report_timing_summary -max_paths 10  -file $out/soc_route_timing_summary.rpt
report_timing -max_paths 10 -nworst 1 -path_type full -input_pins -file $out/soc_route_timing_paths.rpt
report_design_analysis -logic_level_distribution -file $out/soc_route_logic_levels.rpt
check_timing -verbose                -file $out/soc_route_check_timing.rpt
note $summary ""
path_summary $summary "SoC post-route"
close_design

# ---------------- Run 2: core only, synthesized ----------------
synth_design -top rv32i_core -part $part -mode out_of_context
note $summary ""
note $summary "Latches after synthesis (core): [llength [all_latches]]"
report_utilization              -file $out/core_synth_utilization.rpt
report_utilization -hierarchical -file $out/core_synth_utilization_hier.rpt
close_design

close $summary
puts "Baseline complete. See $out/summary.txt"
