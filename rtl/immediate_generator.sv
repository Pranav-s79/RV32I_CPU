`timescale 1ns/1ps
// immediate_generator.sv
// Rebuilds the 32-bit sign-extended immediate from the scattered instruction
// bits. RISC-V always keeps the sign bit in instr[31], so sign extension is
// just copying instr[31] into the upper bits.
//
// Circuit: a 5-input multiplexer of rewired bit fields. No arithmetic.

module immediate_generator
    import rv32i_pkg::*;
(
    input  logic [31:0] instr,
    input  imm_type_e   imm_type,
    output logic [31:0] imm
);

    always_comb begin
        case (imm_type)
            // I-type: ADDI, loads, JALR, shifts (shamt = imm[4:0])
            IMM_I: imm = {{20{instr[31]}}, instr[31:20]};
            // S-type: stores. Immediate split around rd's position.
            IMM_S: imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            // B-type: branches. Offset in multiples of 2, bit 0 always 0.
            IMM_B: imm = {{19{instr[31]}}, instr[31], instr[7],
                          instr[30:25], instr[11:8], 1'b0};
            // U-type: LUI, AUIPC. Upper 20 bits, low 12 bits zero.
            IMM_U: imm = {instr[31:12], 12'b0};
            // J-type: JAL. Offset in multiples of 2, bit 0 always 0.
            IMM_J: imm = {{11{instr[31]}}, instr[31], instr[19:12],
                          instr[20], instr[30:21], 1'b0};
            default: imm = 32'h0000_0000;
        endcase
    end

endmodule
