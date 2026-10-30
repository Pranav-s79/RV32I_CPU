// tb_immediate_generator.sv
// Checks immediate extraction for all five formats:
//   1. Instructions encoded by the GNU assembler (riscv64-unknown-elf-as),
//      with the immediate written in the source.
//   2. Random immediates packed into instructions by an encoder written in
//      this testbench (the inverse operation of the RTL).
`timescale 1ns/1ps
`include "tb_check.svh"

module tb_immediate_generator;
    import rv32i_pkg::*;

    int checks = 0;
    int errors = 0;

    logic [31:0] instr, imm;
    imm_type_e   imm_type;

    immediate_generator dut (.*);

    task automatic t(logic [31:0] ins, imm_type_e ty, logic [31:0] expected, string label);
        instr = ins; imm_type = ty;
        #1;
        `CHECK(label, imm, expected)
    endtask

    // ---- Encoders: place an immediate's bits where each format stores them ----
    function automatic logic [31:0] enc_i(logic [11:0] v, logic [31:0] other);
        return {v, other[19:0]};
    endfunction
    function automatic logic [31:0] enc_s(logic [11:0] v, logic [31:0] other);
        return {v[11:5], other[24:12], v[4:0], other[6:0]};
    endfunction
    function automatic logic [31:0] enc_b(logic [12:0] v, logic [31:0] other);
        return {v[12], v[10:5], other[24:12], v[4:1], v[11], other[6:0]};
    endfunction
    function automatic logic [31:0] enc_u(logic [19:0] v, logic [31:0] other);
        return {v, other[11:0]};
    endfunction
    function automatic logic [31:0] enc_j(logic [20:0] v, logic [31:0] other);
        return {v[20], v[10:1], v[11], v[19:12], other[11:0]};
    endfunction

    initial begin
        $dumpfile("build/sim/tb_immediate_generator.vcd");
        $dumpvars(0, tb_immediate_generator);

        // ---- Assembler-encoded instructions ----
        t(32'hfff00093, IMM_I, 32'hFFFF_FFFF, "addi ra,zero,-1");
        t(32'h80012093, IMM_I, 32'hFFFF_F800, "slti ra,sp,-2048");
        t(32'h7ff13093, IMM_I, 32'h0000_07FF, "sltiu ra,sp,2047");
        t(32'h41f15093, IMM_I, 32'h0000_041F, "srai imm field = 0x41F (shamt in [4:0])");
        t(32'hfff08283, IMM_I, 32'hFFFF_FFFF, "lb t0,-1(ra)");
        t(32'hfff28067, IMM_I, 32'hFFFF_FFFF, "jalr zero,-1(t0)");
        t(32'hfe508fa3, IMM_S, 32'hFFFF_FFFF, "sb t0,-1(ra)");
        t(32'h00509123, IMM_S, 32'h0000_0002, "sh t0,2(ra)");
        t(32'h0050a223, IMM_S, 32'h0000_0004, "sw t0,4(ra)");
        t(32'h00208463, IMM_B, 32'h0000_0008, "beq +8");
        t(32'hfe209ee3, IMM_B, 32'hFFFF_FFFC, "bne -4");
        t(32'h7e20cfe3, IMM_B, 32'h0000_0FFE, "blt +4094 (max)");
        t(32'h8020d063, IMM_B, 32'hFFFF_F000, "bge -4096 (min)");
        t(32'h0020e163, IMM_B, 32'h0000_0002, "bltu +2");
        t(32'h001000ef, IMM_J, 32'h0000_0800, "jal +2048");
        t(32'h8000006f, IMM_J, 32'hFFF0_0000, "jal -1048576 (min)");
        t(32'h7ffff0ef, IMM_J, 32'h000F_FFFE, "jal +1048574 (max)");
        t(32'hfffff3b7, IMM_U, 32'hFFFF_F000, "lui 0xfffff");
        t(32'h123453b7, IMM_U, 32'h1234_5000, "lui 0x12345");
        t(32'h80000397, IMM_U, 32'h8000_0000, "auipc 0x80000");

        // ---- Random immediates through the encoders ----
        for (int n = 0; n < 2000; n++) begin
            logic [31:0] other;
            logic [11:0] v12;
            logic [12:0] v13;
            logic [19:0] v20;
            logic [20:0] v21;
            other = $urandom;
            v12 = 12'($urandom);
            v13 = {13'($urandom)} & ~13'd1;         // B offsets are even
            v20 = 20'($urandom);
            v21 = {21'($urandom)} & ~21'd1;         // J offsets are even
            t(enc_i(v12, other), IMM_I, {{20{v12[11]}}, v12}, "random I");
            t(enc_s(v12, other), IMM_S, {{20{v12[11]}}, v12}, "random S");
            t(enc_b(v13, other), IMM_B, {{19{v13[12]}}, v13}, "random B");
            t(enc_u(v20, other), IMM_U, {v20, 12'b0},          "random U");
            t(enc_j(v21, other), IMM_J, {{11{v21[20]}}, v21}, "random J");
        end

        `TB_FINISH("tb_immediate_generator")
    end

endmodule
