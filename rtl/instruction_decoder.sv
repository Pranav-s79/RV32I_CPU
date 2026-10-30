`timescale 1ns/1ps
// instruction_decoder.sv
// Splits a 32-bit instruction into its fixed fields. Pure wiring: no gates.
//
// RISC-V keeps rs1, rs2, rd, funct3 and the opcode in the same bit positions
// in every format, so the register file can be read before the control unit
// has even decided what the instruction is.
//
//  31      25 24  20 19  15 14  12 11   7 6     0
// [ funct7   |  rs2 |  rs1 |funct3|  rd  | opcode ]   R-type

module instruction_decoder (
    input  logic [31:0] instr,
    output logic [6:0]  opcode,
    output logic [4:0]  rd,
    output logic [2:0]  funct3,
    output logic [4:0]  rs1,
    output logic [4:0]  rs2,
    output logic [6:0]  funct7,
    output logic [11:0] funct12     // instr[31:20]; identifies ECALL/EBREAK
);

    assign opcode  = instr[6:0];
    assign rd      = instr[11:7];
    assign funct3  = instr[14:12];
    assign rs1     = instr[19:15];
    assign rs2     = instr[24:20];
    assign funct7  = instr[31:25];
    assign funct12 = instr[31:20];

endmodule
