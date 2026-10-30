// tb_branch_unit.sv
// Checks all six branch conditions (taken and not taken), signed vs.
// unsigned edge cases, the branch-enable input, and random operands.
`timescale 1ns/1ps
`include "tb_check.svh"

module tb_branch_unit;
    import rv32i_pkg::*;

    int checks = 0;
    int errors = 0;

    logic        branch, taken;
    logic [2:0]  funct3;
    logic [31:0] rs1_data, rs2_data;

    branch_unit dut (.*);

    // Reference: signed compare done by flipping the sign bit, which maps
    // two's-complement order onto unsigned order.
    function automatic logic ref_taken(logic [2:0] f3, logic [31:0] x, logic [31:0] y);
        logic lt_s, lt_u;
        lt_u = x < y;
        lt_s = (x ^ 32'h8000_0000) < (y ^ 32'h8000_0000);
        case (f3)
            3'b000:  return x == y;
            3'b001:  return x != y;
            3'b100:  return lt_s;
            3'b101:  return !lt_s;
            3'b110:  return lt_u;
            3'b111:  return !lt_u;
            default: return 1'b0;
        endcase
    endfunction

    task automatic t(logic [2:0] f3, logic [31:0] x, logic [31:0] y, logic expected, string label);
        branch = 1; funct3 = f3; rs1_data = x; rs2_data = y;
        #1;
        `CHECK(label, taken, expected)
    endtask

    initial begin
        $dumpfile("build/sim/tb_branch_unit.vcd");
        $dumpvars(0, tb_branch_unit);

        t(F3_BEQ,  32'd7,         32'd7,         1, "BEQ equal -> taken");
        t(F3_BEQ,  32'd7,         32'd8,         0, "BEQ differ -> not taken");
        t(F3_BNE,  32'd7,         32'd8,         1, "BNE differ -> taken");
        t(F3_BNE,  32'd7,         32'd7,         0, "BNE equal -> not taken");
        t(F3_BLT,  32'hFFFF_FFFF, 32'd0,         1, "BLT -1 < 0");
        t(F3_BLT,  32'd0,         32'hFFFF_FFFF, 0, "BLT 0 < -1 false");
        t(F3_BLT,  32'h8000_0000, 32'h7FFF_FFFF, 1, "BLT min < max");
        t(F3_BLT,  32'd5,         32'd5,         0, "BLT equal false");
        t(F3_BGE,  32'd5,         32'd5,         1, "BGE equal -> taken");
        t(F3_BGE,  32'd0,         32'hFFFF_FFFF, 1, "BGE 0 >= -1");
        t(F3_BGE,  32'hFFFF_FFFF, 32'd0,         0, "BGE -1 >= 0 false");
        t(F3_BLTU, 32'd0,         32'hFFFF_FFFF, 1, "BLTU 0 < 0xFFFFFFFF");
        t(F3_BLTU, 32'hFFFF_FFFF, 32'd0,         0, "BLTU 0xFFFFFFFF < 0 false");
        t(F3_BLTU, 32'd5,         32'd5,         0, "BLTU equal false");
        t(F3_BGEU, 32'hFFFF_FFFF, 32'd0,         1, "BGEU 0xFFFFFFFF >= 0");
        t(F3_BGEU, 32'd5,         32'd5,         1, "BGEU equal -> taken");
        t(F3_BGEU, 32'd0,         32'd1,         0, "BGEU 0 >= 1 false");

        // branch = 0 must never report taken (e.g. for non-branch instructions)
        branch = 0; funct3 = F3_BEQ; rs1_data = 1; rs2_data = 1; #1;
        `CHECK("branch=0 -> not taken", taken, 1'b0)

        // Reserved funct3 encodings never report taken
        t(3'b010, 32'd1, 32'd1, 0, "reserved funct3 010");
        t(3'b011, 32'd1, 32'd1, 0, "reserved funct3 011");

        for (int n = 0; n < 3000; n++) begin
            logic [2:0]  f3;
            logic [31:0] x, y;
            f3 = 3'($urandom_range(0, 7));
            x = $urandom;
            y = (n % 5 == 0) ? x : $urandom;
            t(f3, x, y, ref_taken(f3, x, y), "random vs reference");
        end

        `TB_FINISH("tb_branch_unit")
    end

endmodule
