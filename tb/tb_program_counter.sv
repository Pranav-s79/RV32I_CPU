// tb_program_counter.sv
// Checks: reset value, update on enable, hold when disabled, reset priority.
`timescale 1ns/1ps
`include "tb_check.svh"

module tb_program_counter;

    int checks = 0;
    int errors = 0;

    localparam logic [31:0] RV = 32'h0000_0100;   // non-zero to prove the parameter works

    logic        clk = 0;
    logic        reset, enable;
    logic [31:0] next_pc, pc;

    program_counter #(.RESET_VECTOR(RV)) dut (.*);

    always #5 clk = ~clk;

    // Apply inputs away from the clock edge, then wait for the edge.
    task automatic step(input logic r, input logic en, input logic [31:0] npc);
        @(negedge clk);
        reset = r; enable = en; next_pc = npc;
        @(posedge clk);
        #1;
    endtask

    initial begin
        $dumpfile("build/sim/tb_program_counter.vcd");
        $dumpvars(0, tb_program_counter);

        step(1, 0, 32'hDEAD_BEEF);
        `CHECK("reset loads RESET_VECTOR", pc, RV)

        step(0, 1, RV + 4);
        `CHECK("enable: pc <= next_pc (pc+4)", pc, RV + 32'd4)

        step(0, 1, 32'h0000_0800);
        `CHECK("enable: redirect to branch target", pc, 32'h0000_0800)

        step(0, 0, 32'h1234_5678);
        `CHECK("enable=0 holds value", pc, 32'h0000_0800)
        step(0, 0, 32'h0000_0000);
        `CHECK("enable=0 holds value (2nd cycle)", pc, 32'h0000_0800)

        step(1, 1, 32'hFFFF_FFFC);
        `CHECK("reset has priority over enable", pc, RV)

        step(0, 1, 32'hFFFF_FFFC);
        `CHECK("full 32-bit value", pc, 32'hFFFF_FFFC)

        // Value only changes at the clock edge, not when next_pc changes.
        @(negedge clk);
        next_pc = 32'h0000_0040;
        #2;
        `CHECK("no change between clock edges", pc, 32'hFFFF_FFFC)
        @(posedge clk); #1;
        `CHECK("changes at rising edge", pc, 32'h0000_0040)

        `TB_FINISH("tb_program_counter")
    end

endmodule
