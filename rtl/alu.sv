`timescale 1ns/1ps
// alu.sv
// Arithmetic Logic Unit. Purely combinational: result changes whenever
// a, b, or op change.
//
// Circuit: every operation is computed in parallel (an adder, a subtractor,
// shifters, comparators, AND/OR/XOR gates) and a multiplexer driven by 'op'
// picks one result. Synthesis shares hardware where it can.
//
// Signedness: a and b are plain bit vectors. Only SLT and SRA treat them as
// two's-complement signed numbers, using $signed(). ADD/SUB give the same
// bits whether the inputs are signed or unsigned, so they need no special case.

module alu
    import rv32i_pkg::*;
(
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  alu_op_e     op,
    output logic [31:0] result
);

    // Shifts use only the low 5 bits of b (0..31). For SLLI/SRLI/SRAI that
    // is the shamt field; for SLL/SRL/SRA it is rs2[4:0], as the ISA requires.
    logic [4:0] shamt;
    assign shamt = b[4:0];

    always_comb begin
        case (op)
            ALU_ADD:  result = a + b;
            ALU_SUB:  result = a - b;
            ALU_SLL:  result = a << shamt;
            ALU_SLT:  result = {31'b0, $signed(a) < $signed(b)};
            ALU_SLTU: result = {31'b0, a < b};
            ALU_XOR:  result = a ^ b;
            ALU_SRL:  result = a >> shamt;                  // fills with 0
            ALU_SRA:  result = $signed(a) >>> shamt;        // fills with sign bit
            ALU_OR:   result = a | b;
            ALU_AND:  result = a & b;
            default:  result = 32'h0000_0000;
        endcase
    end

endmodule
