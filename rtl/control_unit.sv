`timescale 1ns/1ps
// control_unit.sv
// Main decoder: turns opcode/funct3/funct7 into the control signals that
// steer the datapath, and flags every encoding that is not legal RV32I.
//
// Circuit: purely combinational lookup logic. Think of it as a truth table
// from instruction bits to control wires.
//
// Illegal-instruction policy: anything that is not exactly an RV32I
// encoding sets 'illegal' and forces all state-changing controls to 0.
// The core then raises an illegal-instruction trap. Nothing is turned
// into a silent NOP. Examples that are illegal here:
//   - unknown opcodes (including 0x00000000 and 0xFFFFFFFF)
//   - M-extension (funct7 = 0000001), compressed (instr[1:0] != 11)
//   - reserved funct3 values for loads, stores, branches, JALR
//   - SLLI/SRLI/SRAI with a bad funct7 (incl. shamt[5] = 1)
//   - FENCE.I (Zifencei) and CSR instructions (Zicsr): not part of RV32I base
//   - SYSTEM encodings other than exact ECALL / EBREAK (e.g. MRET, WFI)

module control_unit
    import rv32i_pkg::*;
(
    input  logic [6:0]  opcode,
    input  logic [2:0]  funct3,
    input  logic [6:0]  funct7,
    input  logic [4:0]  rd,
    input  logic [4:0]  rs1,
    input  logic [11:0] funct12,

    output logic        reg_write,  // write rd at the end of the cycle
    output alu_a_sel_e  alu_a_sel,
    output alu_b_sel_e  alu_b_sel,
    output alu_op_e     alu_op,
    output imm_type_e   imm_type,
    output logic        mem_read,   // load
    output logic        mem_write,  // store
    output wb_sel_e     wb_sel,
    output logic        branch,     // conditional branch
    output logic        jal,
    output logic        jalr,
    output logic        ecall,
    output logic        ebreak,
    output logic        illegal
);

    // ALU operation implied by funct3 for OP / OP-IMM (ADD/SRL variants;
    // SUB and SRA are chosen below using funct7).
    alu_op_e funct3_op;

    always_comb begin
        case (funct3)
            3'b000:  funct3_op = ALU_ADD;
            3'b001:  funct3_op = ALU_SLL;
            3'b010:  funct3_op = ALU_SLT;
            3'b011:  funct3_op = ALU_SLTU;
            3'b100:  funct3_op = ALU_XOR;
            3'b101:  funct3_op = ALU_SRL;
            3'b110:  funct3_op = ALU_OR;
            default: funct3_op = ALU_AND;   // 3'b111
        endcase
    end

    always_comb begin
        // Defaults: do nothing. Every output is assigned on every path,
        // so no latches can be inferred.
        reg_write = 1'b0;
        alu_a_sel = A_RS1;
        alu_b_sel = B_RS2;
        alu_op    = ALU_ADD;
        imm_type  = IMM_I;
        mem_read  = 1'b0;
        mem_write = 1'b0;
        wb_sel    = WB_ALU;
        branch    = 1'b0;
        jal       = 1'b0;
        jalr      = 1'b0;
        ecall     = 1'b0;
        ebreak    = 1'b0;
        illegal   = 1'b0;

        case (opcode)
            OPC_LUI: begin                      // rd = imm
                reg_write = 1'b1;
                alu_a_sel = A_ZERO;
                alu_b_sel = B_IMM;
                imm_type  = IMM_U;
            end

            OPC_AUIPC: begin                    // rd = pc + imm
                reg_write = 1'b1;
                alu_a_sel = A_PC;
                alu_b_sel = B_IMM;
                imm_type  = IMM_U;
            end

            OPC_JAL: begin                      // rd = pc + 4; pc = pc + imm
                reg_write = 1'b1;
                jal       = 1'b1;
                imm_type  = IMM_J;
                wb_sel    = WB_PC4;
            end

            OPC_JALR: begin                     // rd = pc + 4; pc = (rs1 + imm) & ~1
                imm_type  = IMM_I;
                alu_b_sel = B_IMM;
                if (funct3 == 3'b000) begin
                    reg_write = 1'b1;
                    jalr      = 1'b1;
                    wb_sel    = WB_PC4;
                end else begin
                    illegal = 1'b1;
                end
            end

            OPC_BRANCH: begin                   // if (cond) pc = pc + imm
                imm_type = IMM_B;
                if (funct3 == 3'b010 || funct3 == 3'b011)
                    illegal = 1'b1;
                else
                    branch = 1'b1;
            end

            OPC_LOAD: begin                     // rd = mem[rs1 + imm]
                imm_type  = IMM_I;
                alu_b_sel = B_IMM;
                case (funct3)
                    F3_B, F3_H, F3_W, F3_BU, F3_HU: begin
                        mem_read  = 1'b1;
                        reg_write = 1'b1;
                        wb_sel    = WB_MEM;
                    end
                    default: illegal = 1'b1;
                endcase
            end

            OPC_STORE: begin                    // mem[rs1 + imm] = rs2
                imm_type  = IMM_S;
                alu_b_sel = B_IMM;
                case (funct3)
                    F3_B, F3_H, F3_W: mem_write = 1'b1;
                    default:          illegal   = 1'b1;
                endcase
            end

            OPC_OP_IMM: begin                   // rd = rs1 op imm
                imm_type  = IMM_I;
                alu_b_sel = B_IMM;
                alu_op    = funct3_op;
                reg_write = 1'b1;
                if (funct3 == 3'b001) begin             // SLLI
                    if (funct7 != F7_BASE) illegal = 1'b1;
                end else if (funct3 == 3'b101) begin    // SRLI / SRAI
                    if (funct7 == F7_ALT)
                        alu_op = ALU_SRA;
                    else if (funct7 != F7_BASE)
                        illegal = 1'b1;
                end
            end

            OPC_OP: begin                       // rd = rs1 op rs2
                alu_op    = funct3_op;
                reg_write = 1'b1;
                if (funct7 == F7_ALT && funct3 == 3'b000)
                    alu_op = ALU_SUB;
                else if (funct7 == F7_ALT && funct3 == 3'b101)
                    alu_op = ALU_SRA;
                else if (funct7 != F7_BASE)
                    illegal = 1'b1;
            end

            OPC_MISC_MEM: begin
                // FENCE (funct3 = 000). This core executes one instruction
                // at a time, in order, with no caches or write buffers, so
                // every memory access is already complete and visible before
                // the next one starts. FENCE therefore has nothing to wait
                // for and changes no state. Per the spec, the unused fm/rs1/rd
                // fields are ignored. FENCE.I (funct3 = 001) is Zifencei,
                // which is not implemented.
                if (funct3 != 3'b000)
                    illegal = 1'b1;
            end

            OPC_SYSTEM: begin
                if (funct3 == 3'b000 && rd == 5'd0 && rs1 == 5'd0 && funct12 == 12'h000)
                    ecall = 1'b1;
                else if (funct3 == 3'b000 && rd == 5'd0 && rs1 == 5'd0 && funct12 == 12'h001)
                    ebreak = 1'b1;
                else
                    illegal = 1'b1;             // CSRs, MRET, WFI, ...
            end

            default: illegal = 1'b1;
        endcase

        // An illegal instruction must not change any state.
        if (illegal) begin
            reg_write = 1'b0;
            mem_read  = 1'b0;
            mem_write = 1'b0;
            branch    = 1'b0;
            jal       = 1'b0;
            jalr      = 1'b0;
        end
    end

endmodule
