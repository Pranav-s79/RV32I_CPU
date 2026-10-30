`timescale 1ns/1ps
// branch_unit.sv
// Decides whether a conditional branch is taken by comparing rs1 and rs2.
// Has its own comparators so the ALU stays free (the ALU is not used by
// branches in this design; the target address has its own adder in
// next_pc_logic).
//
// Circuit: one equality comparator, one signed and one unsigned
// less-than comparator, and a mux selected by funct3.

module branch_unit
    import rv32i_pkg::*;
(
    input  logic        branch,     // 1 = this is a BRANCH instruction
    input  logic [2:0]  funct3,     // which comparison
    input  logic [31:0] rs1_data,
    input  logic [31:0] rs2_data,
    output logic        taken
);

    logic eq, lt, ltu;

    assign eq  = (rs1_data == rs2_data);
    assign lt  = ($signed(rs1_data) < $signed(rs2_data));
    assign ltu = (rs1_data < rs2_data);

    always_comb begin
        taken = 1'b0;
        if (branch) begin
            case (funct3)
                F3_BEQ:  taken = eq;
                F3_BNE:  taken = !eq;
                F3_BLT:  taken = lt;
                F3_BGE:  taken = !lt;
                F3_BLTU: taken = ltu;
                F3_BGEU: taken = !ltu;
                default: taken = 1'b0;   // 010/011 are illegal; control_unit flags them
            endcase
        end
    end

endmodule
