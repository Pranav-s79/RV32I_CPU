// tb_next_pc_logic.sv
// Checks next-PC selection: sequential, taken/not-taken branch, JAL, JALR
// (including bit-0 clearing), and misaligned-target detection.
`timescale 1ns/1ps
`include "tb_check.svh"

module tb_next_pc_logic;

    int checks = 0;
    int errors = 0;

    logic [31:0] pc, imm, alu_result;
    logic        branch_taken, jal, jalr;
    logic [31:0] pc_plus4, next_pc, target;
    logic        target_misaligned;

    next_pc_logic dut (.*);

    task automatic t(logic [31:0] p, logic [31:0] i, logic [31:0] alu, logic bt, logic j, logic jr,
                     logic [31:0] exp_next, logic exp_mis, string label);
        pc = p; imm = i; alu_result = alu; branch_taken = bt; jal = j; jalr = jr;
        #1;
        `CHECK({label, " pc_plus4"}, pc_plus4, p + 32'd4)
        `CHECK({label, " next_pc"}, next_pc, exp_next)
        `CHECK({label, " misaligned"}, target_misaligned, exp_mis)
    endtask

    initial begin
        $dumpfile("build/sim/tb_next_pc_logic.vcd");
        $dumpvars(0, tb_next_pc_logic);

        //   pc            imm            alu           bt j jr  expected next   mis
        t(32'h0000_0100, 32'h0000_0040, 32'h0,        0, 0, 0, 32'h0000_0104, 0, "sequential");
        t(32'h0000_0100, 32'h0000_0040, 32'h0,        1, 0, 0, 32'h0000_0140, 0, "branch taken fwd");
        t(32'h0000_0100, 32'hFFFF_FFF0, 32'h0,        1, 0, 0, 32'h0000_00F0, 0, "branch taken back");
        t(32'h0000_0100, 32'h0000_0002, 32'h0,        1, 0, 0, 32'h0000_0102, 1, "branch +2 misaligned");
        t(32'h0000_0100, 32'h0000_0002, 32'h0,        0, 0, 0, 32'h0000_0104, 0, "not taken: no misaligned trap");
        t(32'h0000_0100, 32'h0000_0800, 32'h0,        0, 1, 0, 32'h0000_0900, 0, "JAL");
        t(32'h0000_0100, 32'h0000_0006, 32'h0,        0, 1, 0, 32'h0000_0106, 1, "JAL +6 misaligned");
        t(32'h0000_0100, 32'h0,         32'h0000_0200, 0, 0, 1, 32'h0000_0200, 0, "JALR");
        t(32'h0000_0100, 32'h0,         32'h0000_0201, 0, 0, 1, 32'h0000_0200, 0, "JALR clears bit 0");
        t(32'h0000_0100, 32'h0,         32'h0000_0202, 0, 0, 1, 32'h0000_0202, 1, "JALR bit1 set misaligned");
        t(32'h0000_0100, 32'h0,         32'h0000_0203, 0, 0, 1, 32'h0000_0202, 1, "JALR 0x203 -> 0x202 misaligned");
        t(32'hFFFF_FFFC, 32'h0,         32'h0,         0, 0, 0, 32'h0000_0000, 0, "pc+4 wraps at 2^32");

        // 'target' is reported even when not redirecting (used for trap tval)
        pc = 32'h0000_0100; imm = 32'h0000_0010; alu_result = 32'h0000_0333; jalr = 1; jal = 0; branch_taken = 0;
        #1;
        `CHECK("target output for JALR = alu & ~1", target, 32'h0000_0332)
        jalr = 0; #1;
        `CHECK("target output otherwise = pc + imm", target, 32'h0000_0110)

        `TB_FINISH("tb_next_pc_logic")
    end

endmodule
