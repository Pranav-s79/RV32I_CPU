// tb_alu.sv
// Checks every ALU operation with hand-computed corner cases, then with
// random operands against a reference model written differently from the
// RTL (sign handled through explicit bit logic, not $signed).
`timescale 1ns/1ps
`include "tb_check.svh"

module tb_alu;
    import rv32i_pkg::*;

    int checks = 0;
    int errors = 0;

    logic [31:0] a, b, result;
    alu_op_e     op;

    alu dut (.*);

    // Independent reference model.
    function automatic logic [31:0] ref_alu(alu_op_e o, logic [31:0] x, logic [31:0] y);
        logic [63:0] ext;
        logic        lt_signed;
        logic [4:0]  sh;
        sh = y[4:0];
        // Signed less-than without $signed: if the sign bits differ, the
        // negative one (sign = 1) is smaller; otherwise compare as unsigned.
        lt_signed = (x[31] != y[31]) ? x[31] : (x < y);
        ext = {{32{x[31]}}, x};                 // sign-extend to 64 bits for SRA
        case (o)
            ALU_ADD:  return x + y;
            ALU_SUB:  return x + (~y) + 32'd1;  // two's complement subtract
            ALU_SLL:  return x << sh;
            ALU_SLT:  return {31'b0, lt_signed};
            ALU_SLTU: return {31'b0, x < y};
            ALU_XOR:  return x ^ y;
            ALU_SRL:  return x >> sh;
            ALU_SRA:  return 32'(ext >> sh);
            ALU_OR:   return x | y;
            ALU_AND:  return x & y;
            default:  return 32'h0;
        endcase
    endfunction

    task automatic t(alu_op_e o, logic [31:0] x, logic [31:0] y, logic [31:0] expected, string label);
        op = o; a = x; b = y;
        #1;
        `CHECK(label, result, expected)
    endtask

    initial begin
        $dumpfile("build/sim/tb_alu.vcd");
        $dumpvars(0, tb_alu);

        // ---- Hand-computed corner cases (expected values written by hand) ----
        t(ALU_ADD, 32'd5,          32'd3,          32'd8,          "ADD 5+3");
        t(ALU_ADD, 32'hFFFF_FFFF,  32'd1,          32'h0,          "ADD wraps (-1+1)");
        t(ALU_ADD, 32'h7FFF_FFFF,  32'd1,          32'h8000_0000,  "ADD signed overflow");
        t(ALU_SUB, 32'd3,          32'd5,          32'hFFFF_FFFE,  "SUB 3-5 = -2");
        t(ALU_SUB, 32'h8000_0000,  32'd1,          32'h7FFF_FFFF,  "SUB min-1 wraps");
        t(ALU_SUB, 32'd0,          32'd0,          32'd0,          "SUB 0-0");
        t(ALU_SLL, 32'd1,          32'd31,         32'h8000_0000,  "SLL by 31");
        t(ALU_SLL, 32'hFFFF_FFFF,  32'd0,          32'hFFFF_FFFF,  "SLL by 0");
        t(ALU_SLL, 32'd1,          32'd33,         32'd2,          "SLL uses only b[4:0] (33->1)");
        t(ALU_SRL, 32'h8000_0000,  32'd31,         32'd1,          "SRL by 31");
        t(ALU_SRL, 32'h8000_0000,  32'd4,          32'h0800_0000,  "SRL zero-fills");
        t(ALU_SRA, 32'h8000_0000,  32'd4,          32'hF800_0000,  "SRA sign-fills");
        t(ALU_SRA, 32'h8000_0000,  32'd31,         32'hFFFF_FFFF,  "SRA by 31 negative");
        t(ALU_SRA, 32'h7FFF_FFFF,  32'd31,         32'd0,          "SRA by 31 positive");
        t(ALU_SRA, 32'hF000_0000,  32'h0000_0400,  32'hF000_0000,  "SRA uses only b[4:0] (1024->0)");
        t(ALU_SLT, 32'hFFFF_FFFF,  32'd1,          32'd1,          "SLT -1 < 1");
        t(ALU_SLT, 32'd1,          32'hFFFF_FFFF,  32'd0,          "SLT 1 < -1 false");
        t(ALU_SLT, 32'h8000_0000,  32'h7FFF_FFFF,  32'd1,          "SLT min < max");
        t(ALU_SLT, 32'd5,          32'd5,          32'd0,          "SLT equal");
        t(ALU_SLTU, 32'hFFFF_FFFF, 32'd1,          32'd0,          "SLTU 0xFFFFFFFF < 1 false");
        t(ALU_SLTU, 32'd1,         32'hFFFF_FFFF,  32'd1,          "SLTU 1 < 0xFFFFFFFF");
        t(ALU_SLTU, 32'd0,         32'd0,          32'd0,          "SLTU equal");
        t(ALU_XOR, 32'hF0F0_F0F0,  32'hFF00_FF00,  32'h0FF0_0FF0,  "XOR");
        t(ALU_OR,  32'hF0F0_F0F0,  32'h0F0F_0000,  32'hFFFF_F0F0,  "OR");
        t(ALU_AND, 32'hF0F0_F0F0,  32'hFF00_FF00,  32'hF000_F000,  "AND");

        // ---- Random operands vs. reference model ----
        for (int n = 0; n < 5000; n++) begin
            alu_op_e o;
            logic [31:0] x, y;
            case ($urandom_range(0, 9))
                0: o = ALU_ADD;  1: o = ALU_SUB;  2: o = ALU_SLL;  3: o = ALU_SLT;
                4: o = ALU_SLTU; 5: o = ALU_XOR;  6: o = ALU_SRL;  7: o = ALU_SRA;
                8: o = ALU_OR;   default: o = ALU_AND;
            endcase
            x = $urandom;
            y = (n % 4 == 0) ? 32'($urandom_range(0, 40)) : $urandom;  // exercise small shift amounts
            if (n % 7 == 0) y = x;                                    // exercise equality
            op = o; a = x; b = y;
            #1;
            `CHECK("random vs reference", result, ref_alu(o, x, y))
        end

        `TB_FINISH("tb_alu")
    end

endmodule
