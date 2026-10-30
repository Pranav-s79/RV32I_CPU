`timescale 1ns/1ps
// next_pc_logic.sv
// Chooses the address of the next instruction.
//
//   default           : pc + 4
//   taken branch, JAL : pc + imm          (imm is the B- or J-type offset)
//   JALR              : (rs1 + imm) & ~1  (the sum comes from the ALU)
//
// Also reports when a jump/branch target is not 4-byte aligned. RV32I without
// the C extension requires 4-byte aligned instructions, so such a jump must
// raise an instruction-address-misaligned exception ON the jump instruction.
//
// Circuit: two 32-bit adders (pc+4, pc+imm) and two 2:1 muxes.

module next_pc_logic (
    input  logic [31:0] pc,
    input  logic [31:0] imm,
    input  logic [31:0] alu_result,     // rs1 + imm for JALR
    input  logic        branch_taken,
    input  logic        jal,
    input  logic        jalr,
    output logic [31:0] pc_plus4,       // also the link address for JAL/JALR
    output logic [31:0] next_pc,
    output logic [31:0] target,         // redirect target (for exception reporting)
    output logic        target_misaligned
);

    logic [31:0] pc_rel_target;
    logic        redirect;

    assign pc_plus4      = pc + 32'd4;
    assign pc_rel_target = pc + imm;

    // JALR clears bit 0 of the computed address (RV32I spec, JALR).
    assign target   = jalr ? {alu_result[31:1], 1'b0} : pc_rel_target;
    assign redirect = jal || jalr || branch_taken;

    assign next_pc           = redirect ? target : pc_plus4;
    assign target_misaligned = redirect && (target[1:0] != 2'b00);

endmodule
