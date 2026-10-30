// tb_rv32i_core.sv
// Runs one program on the full system (rv32i_soc_top) and records:
//   - one trace line per retired instruction (PC, instruction, rd write,
//     memory write), in the same format as scripts/rv32i_iss.py
//   - the trap that stopped the program
//   - final register file, LED register, and non-zero data memory words
// scripts/run_core_tests.py compares this file against the Python model.
//
// The testbench also checks, by itself:
//   - the program halts before +MAX_CYCLES
//   - trap cause (if +EXPECT_CAUSE=<n> is given)
//   - a0 / x10 at halt (if +EXPECT_A0=<hex> is given)
//   - after a second reset: PC = 0, not halted, trap cause cleared
//
// Plusargs:
//   +PROGRAM=<file.hex>   (required) instruction memory image
//   +TRACE=<file>         (required) output trace/state file
//   +VCD=<file>           optional waveform dump
//   +MAX_CYCLES=<n>       default 100000
//   +EXPECT_CAUSE=<n>     optional
//   +EXPECT_A0=<hex>      optional
`timescale 1ns/1ps
`include "tb_check.svh"

module tb_rv32i_core;

    int checks = 0;
    int errors = 0;

    localparam logic [31:0] DMEM_BASE = 32'h0001_0000;
    localparam int          DMEM_WORDS = 1024;

    logic       clk = 0;
    logic       reset;
    logic [3:0] led;
    logic       halted;
    logic [3:0] trap_cause;

    rv32i_soc_top dut (
        .clk        (clk),
        .reset      (reset),
        .led        (led),
        .halted     (halted),
        .trap_cause (trap_cause)
    );

    always #5 clk = ~clk;       // 100 MHz in simulation (timing is not modeled)

    string  program_file, trace_file, vcd_file;
    int     max_cycles, expect_cause;
    logic [31:0] expect_a0;
    bit     has_cause, has_a0;
    int     fd;
    int     cycles;

    // ---------------- Retirement trace ----------------
    // Sampled at the rising edge, BEFORE the nonblocking updates land, so
    // these are the values of the instruction that is completing now.
    always @(posedge clk) begin
        if (!reset && fd != 0 && dut.u_core.commit) begin
            logic [31:0] lane_mask;
            $fwrite(fd, "%08x %08x", dut.u_core.pc, dut.u_core.instr);
            if (dut.u_core.reg_write && dut.u_core.rd != 5'd0)
                $fwrite(fd, " x%0d=%08x", dut.u_core.rd, dut.u_core.wb_data);
            if (dut.u_core.dmem_we) begin
                lane_mask = {{8{dut.u_core.dmem_wstrb[3]}}, {8{dut.u_core.dmem_wstrb[2]}},
                             {8{dut.u_core.dmem_wstrb[1]}}, {8{dut.u_core.dmem_wstrb[0]}}};
                $fwrite(fd, " [%08x]%0x=%08x", dut.u_core.dmem_addr & 32'hFFFF_FFFC,
                        dut.u_core.dmem_wstrb, dut.u_core.dmem_wdata & lane_mask);
            end
            $fwrite(fd, "\n");
        end
    end

    task automatic write_final_state;
        if (halted)
            $fwrite(fd, "TRAP cause=%0d pc=%08x tval=%08x\n",
                    dut.u_core.trap_cause, dut.u_core.trap_pc, dut.u_core.trap_tval);
        else
            $fwrite(fd, "TIMEOUT\n");
        for (int i = 1; i < 32; i++)
            $fwrite(fd, "x%0d=%08x\n", i, dut.u_core.u_regfile.regs[i]);
        $fwrite(fd, "LED=%0x\n", led);
        for (int i = 0; i < DMEM_WORDS; i++)
            if (dut.u_dmem.mem[i] != 32'h0)
                $fwrite(fd, "MEM[%08x]=%08x\n", DMEM_BASE + 4 * i, dut.u_dmem.mem[i]);
    endtask

    initial begin
        if (!$value$plusargs("PROGRAM=%s", program_file)) $fatal(1, "missing +PROGRAM=<file.hex>");
        if (!$value$plusargs("TRACE=%s", trace_file))     $fatal(1, "missing +TRACE=<file>");
        if (!$value$plusargs("MAX_CYCLES=%d", max_cycles)) max_cycles = 100000;
        has_cause = $value$plusargs("EXPECT_CAUSE=%d", expect_cause);
        has_a0    = $value$plusargs("EXPECT_A0=%h", expect_a0);
        if ($value$plusargs("VCD=%s", vcd_file)) begin
            $dumpfile(vcd_file);
            $dumpvars(0, tb_rv32i_core);
        end

        fd = 0;
        reset = 1'b1;

        // Load the program after the memory's own initial block has
        // zero-filled it (that block runs at time 0).
        #1;
        $readmemh(program_file, dut.u_imem.mem);
        fd = $fopen(trace_file, "w");
        if (fd == 0) $fatal(1, "cannot open trace file %s", trace_file);

        // Hold reset for two rising edges, release on a falling edge.
        repeat (2) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;
        `CHECK("PC = reset vector after reset", dut.u_core.pc, 32'h0000_0000)
        `CHECK("not halted after reset", halted, 1'b0)

        cycles = 0;
        while (!halted && cycles < max_cycles) begin
            @(posedge clk);
            cycles++;
        end
        #1;

        `CHECK("halted before MAX_CYCLES", halted, 1'b1)
        if (has_cause) `CHECK("trap cause", trap_cause, expect_cause[3:0])
        if (has_a0)    `CHECK("a0 at halt", dut.u_core.u_regfile.regs[10], expect_a0)

        write_final_state();
        $fclose(fd);
        fd = 0;
        $display("program %s: %0d cycles, cause=%0d pc=%08x tval=%08x a0=%08x led=%b",
                 program_file, cycles, dut.u_core.trap_cause, dut.u_core.trap_pc,
                 dut.u_core.trap_tval, dut.u_core.u_regfile.regs[10], led);

        // Reset again: the core must leave the halted state cleanly.
        @(negedge clk);
        reset = 1'b1;
        @(posedge clk); #1;
        `CHECK("second reset: PC", dut.u_core.pc, 32'h0000_0000)
        `CHECK("second reset: halted cleared", halted, 1'b0)
        `CHECK("second reset: trap cause cleared", trap_cause, 4'd0)
        `CHECK("second reset: LED cleared", led, 4'b0000)

        `TB_FINISH("tb_rv32i_core")
    end

endmodule
