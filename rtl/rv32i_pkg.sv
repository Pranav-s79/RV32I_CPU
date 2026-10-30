`timescale 1ns/1ps
// rv32i_pkg.sv
// Shared constants and types for the single-cycle RV32I core.
// Every other RTL file imports this package, so encodings live in one place.

package rv32i_pkg;

    // ------------------------------------------------------------------
    // Major opcodes: instr[6:0] (RISC-V unprivileged spec, chapter 2)
    // ------------------------------------------------------------------
    localparam logic [6:0] OPC_LUI      = 7'b0110111;
    localparam logic [6:0] OPC_AUIPC    = 7'b0010111;
    localparam logic [6:0] OPC_JAL      = 7'b1101111;
    localparam logic [6:0] OPC_JALR     = 7'b1100111;
    localparam logic [6:0] OPC_BRANCH   = 7'b1100011;
    localparam logic [6:0] OPC_LOAD     = 7'b0000011;
    localparam logic [6:0] OPC_STORE    = 7'b0100011;
    localparam logic [6:0] OPC_OP_IMM   = 7'b0010011;
    localparam logic [6:0] OPC_OP       = 7'b0110011;
    localparam logic [6:0] OPC_MISC_MEM = 7'b0001111;   // FENCE
    localparam logic [6:0] OPC_SYSTEM   = 7'b1110011;   // ECALL, EBREAK

    // funct7 values that are legal in RV32I
    localparam logic [6:0] F7_BASE = 7'b0000000;
    localparam logic [6:0] F7_ALT  = 7'b0100000;        // SUB, SRA, SRAI

    // Load/store width encodings (funct3)
    localparam logic [2:0] F3_B  = 3'b000;
    localparam logic [2:0] F3_H  = 3'b001;
    localparam logic [2:0] F3_W  = 3'b010;
    localparam logic [2:0] F3_BU = 3'b100;
    localparam logic [2:0] F3_HU = 3'b101;

    // Branch condition encodings (funct3)
    localparam logic [2:0] F3_BEQ  = 3'b000;
    localparam logic [2:0] F3_BNE  = 3'b001;
    localparam logic [2:0] F3_BLT  = 3'b100;
    localparam logic [2:0] F3_BGE  = 3'b101;
    localparam logic [2:0] F3_BLTU = 3'b110;
    localparam logic [2:0] F3_BGEU = 3'b111;

    // ------------------------------------------------------------------
    // Datapath control types
    // ------------------------------------------------------------------
    typedef enum logic [3:0] {
        ALU_ADD  = 4'd0,
        ALU_SUB  = 4'd1,
        ALU_SLL  = 4'd2,
        ALU_SLT  = 4'd3,
        ALU_SLTU = 4'd4,
        ALU_XOR  = 4'd5,
        ALU_SRL  = 4'd6,
        ALU_SRA  = 4'd7,
        ALU_OR   = 4'd8,
        ALU_AND  = 4'd9
    } alu_op_e;

    // Which instruction format the immediate comes from
    typedef enum logic [2:0] {
        IMM_I = 3'd0,
        IMM_S = 3'd1,
        IMM_B = 3'd2,
        IMM_U = 3'd3,
        IMM_J = 3'd4
    } imm_type_e;

    // ALU operand A source
    typedef enum logic [1:0] {
        A_RS1  = 2'd0,
        A_PC   = 2'd1,      // AUIPC
        A_ZERO = 2'd2       // LUI  (0 + imm)
    } alu_a_sel_e;

    // ALU operand B source
    typedef enum logic {
        B_RS2 = 1'b0,
        B_IMM = 1'b1
    } alu_b_sel_e;

    // What gets written back to rd
    typedef enum logic [1:0] {
        WB_ALU = 2'd0,      // arithmetic / logic / LUI / AUIPC
        WB_MEM = 2'd1,      // loads
        WB_PC4 = 2'd2       // JAL / JALR link address
    } wb_sel_e;

    // ------------------------------------------------------------------
    // Exception cause codes (same numbers as the RISC-V mcause register)
    // ------------------------------------------------------------------
    localparam logic [3:0] CAUSE_INSTR_MISALIGNED = 4'd0;
    localparam logic [3:0] CAUSE_INSTR_ACCESS     = 4'd1;
    localparam logic [3:0] CAUSE_ILLEGAL_INSTR    = 4'd2;
    localparam logic [3:0] CAUSE_BREAKPOINT       = 4'd3;
    localparam logic [3:0] CAUSE_LOAD_MISALIGNED  = 4'd4;
    localparam logic [3:0] CAUSE_LOAD_ACCESS      = 4'd5;
    localparam logic [3:0] CAUSE_STORE_MISALIGNED = 4'd6;
    localparam logic [3:0] CAUSE_STORE_ACCESS     = 4'd7;
    localparam logic [3:0] CAUSE_ECALL_M          = 4'd11;

endpackage
