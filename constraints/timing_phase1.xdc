# timing_phase1.xdc
# Timing constraint for the out-of-context (OOC) baseline runs.
#
# Clock: 10.000 ns period (100 MHz) on port 'clk'.
#   This is a fixed REFERENCE period, used unchanged for every phase so that
#   results are comparable. It is not a claim that the design meets 100 MHz.
#   The achieved speed is read from the worst negative slack (WNS):
#       estimated Fmax = 1 / (10.000 ns - WNS)
#
# No input/output delays are set: in OOC mode the ports (reset, led, ...)
# are not connected to pins, so only register-to-register paths inside the
# design are timed. For a single-cycle CPU those are the paths that matter
# (PC -> fetch -> decode -> execute -> memory -> writeback -> register).
create_clock -name clk -period 10.000 [get_ports clk]
