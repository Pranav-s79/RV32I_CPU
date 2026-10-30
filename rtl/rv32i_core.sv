`timescale 1ns/1ps
// rv32i_core.sv
// Single-cycle RV32I processor core.
//
// Every instruction is fetched, decoded, executed, and (if needed) accesses
// memory within ONE clock cycle. All architectural state (PC, register file,
// data memory, trap status) updates together at the rising clock edge.
//
// The core has no memories inside it. It talks to the outside through:
//   - an instruction fetch port (imem_*), combinational read
//   - a data port (dmem_*), combinational read, synchronous write
// The SoC (rv32i_soc_top) connects those to real memories and decodes
// addresses. Keeping memories outside lets us synthesize and measure the
// core by itself.
//
// Traps (Phase 1 limitation): there are no CSRs and no trap vector. When an
// instruction raises an exception (illegal instruction, ECALL, EBREAK,
// misaligned or faulting access), the instruction does NOT commit (no rd
// write, no store, no PC update) and the core HALTS. The cause, the PC of
// the trapping instruction, and a trap value are held on trap_* outputs
// until reset. Cause numbers match the RISC-V mcause encoding.

module rv32i_core
    import rv32i_pkg::*;
#(
    parameter logic [31:0] RESET_VECTOR = 32'h0000_0000
) (
    input  logic        clk,
    input  logic        reset,          // synchronous, active high

    // Instruction fetch port
    output logic [31:0] imem_addr,
    input  logic [31:0] imem_rdata,
    input  logic        imem_fault,     // imem_addr is not instruction memory

    // Data port
    output logic [31:0] dmem_addr,      // byte address
    output logic        dmem_re,        // a load is reading this cycle
    output logic        dmem_we,        // commit a store at the clock edge
    output logic [3:0]  dmem_wstrb,
    output logic [31:0] dmem_wdata,
    input  logic [31:0] dmem_rdata,
    input  logic        dmem_fault,     // dmem_addr is not mapped

    // Trap / halt status
    output logic        halted,
    output logic [3:0]  trap_cause,
    output logic [31:0] trap_pc,
    output logic [31:0] trap_tval
);

    // ------------------------------------------------------------------
    // Signals
    // ------------------------------------------------------------------
    logic [31:0] pc, next_pc, pc_plus4, jump_target;
    logic [31:0] instr;

    logic [6:0]  opcode, funct7;
    logic [4:0]  rd, rs1, rs2;
    logic [2:0]  funct3;
    logic [11:0] funct12;

    logic        reg_write, mem_read, mem_write;
    logic        branch, jal, jalr, ecall, ebreak, illegal;
    alu_a_sel_e  alu_a_sel;
    alu_b_sel_e  alu_b_sel;
    alu_op_e     alu_op;
    imm_type_e   imm_type;
    wb_sel_e     wb_sel;

    logic [31:0] imm;
    logic [31:0] rs1_data, rs2_data;
    logic [31:0] alu_a, alu_b, alu_result;
    logic        branch_taken;
    logic        target_misaligned;

    logic [31:0] load_data;
    logic [3:0]  lsu_wstrb;
    logic [31:0] lsu_wdata;
    logic        load_misaligned, store_misaligned;

    logic [31:0] wb_data;

    logic        exception;
    logic [3:0]  exc_cause;
    logic [31:0] exc_tval;
    logic        commit;        // this instruction completes normally

    // ------------------------------------------------------------------
    // Fetch
    // ------------------------------------------------------------------
    program_counter #(.RESET_VECTOR(RESET_VECTOR)) u_pc (
        .clk     (clk),
        .reset   (reset),
        .enable  (commit),
        .next_pc (next_pc),
        .pc      (pc)
    );

    assign imem_addr = pc;
    assign instr     = imem_rdata;

    // ------------------------------------------------------------------
    // Decode
    // ------------------------------------------------------------------
    instruction_decoder u_decoder (
        .instr   (instr),
        .opcode  (opcode),
        .rd      (rd),
        .funct3  (funct3),
        .rs1     (rs1),
        .rs2     (rs2),
        .funct7  (funct7),
        .funct12 (funct12)
    );

    control_unit u_control (
        .opcode    (opcode),
        .funct3    (funct3),
        .funct7    (funct7),
        .rd        (rd),
        .rs1       (rs1),
        .funct12   (funct12),
        .reg_write (reg_write),
        .alu_a_sel (alu_a_sel),
        .alu_b_sel (alu_b_sel),
        .alu_op    (alu_op),
        .imm_type  (imm_type),
        .mem_read  (mem_read),
        .mem_write (mem_write),
        .wb_sel    (wb_sel),
        .branch    (branch),
        .jal       (jal),
        .jalr      (jalr),
        .ecall     (ecall),
        .ebreak    (ebreak),
        .illegal   (illegal)
    );

    immediate_generator u_immgen (
        .instr    (instr),
        .imm_type (imm_type),
        .imm      (imm)
    );

    register_file u_regfile (
        .clk      (clk),
        .we       (reg_write && commit),
        .rs1_addr (rs1),
        .rs2_addr (rs2),
        .rd_addr  (rd),
        .rd_data  (wb_data),
        .rs1_data (rs1_data),
        .rs2_data (rs2_data)
    );

    // ------------------------------------------------------------------
    // Execute
    // ------------------------------------------------------------------
    always_comb begin
        case (alu_a_sel)
            A_PC:    alu_a = pc;
            A_ZERO:  alu_a = 32'h0000_0000;
            default: alu_a = rs1_data;
        endcase
    end

    assign alu_b = (alu_b_sel == B_IMM) ? imm : rs2_data;

    alu u_alu (
        .a      (alu_a),
        .b      (alu_b),
        .op     (alu_op),
        .result (alu_result)
    );

    branch_unit u_branch (
        .branch   (branch),
        .funct3   (funct3),
        .rs1_data (rs1_data),
        .rs2_data (rs2_data),
        .taken    (branch_taken)
    );

    next_pc_logic u_next_pc (
        .pc                (pc),
        .imm               (imm),
        .alu_result        (alu_result),
        .branch_taken      (branch_taken),
        .jal               (jal),
        .jalr              (jalr),
        .pc_plus4          (pc_plus4),
        .next_pc           (next_pc),
        .target            (jump_target),
        .target_misaligned (target_misaligned)
    );

    // ------------------------------------------------------------------
    // Memory
    // ------------------------------------------------------------------
    load_store_unit u_lsu (
        .mem_read         (mem_read),
        .mem_write        (mem_write),
        .funct3           (funct3),
        .addr             (alu_result),
        .store_data       (rs2_data),
        .mem_rdata        (dmem_rdata),
        .wstrb            (lsu_wstrb),
        .mem_wdata        (lsu_wdata),
        .load_data        (load_data),
        .load_misaligned  (load_misaligned),
        .store_misaligned (store_misaligned)
    );

    assign dmem_addr  = alu_result;
    assign dmem_re    = mem_read && !halted;
    assign dmem_we    = mem_write && commit;
    assign dmem_wstrb = lsu_wstrb;
    assign dmem_wdata = lsu_wdata;

    // ------------------------------------------------------------------
    // Write back
    // ------------------------------------------------------------------
    always_comb begin
        case (wb_sel)
            WB_MEM:  wb_data = load_data;
            WB_PC4:  wb_data = pc_plus4;
            default: wb_data = alu_result;
        endcase
    end

    // ------------------------------------------------------------------
    // Exceptions
    // Checked in priority order (highest first). Only the first matching
    // cause is reported.
    // ------------------------------------------------------------------
    always_comb begin
        exception = 1'b1;
        exc_cause = CAUSE_ILLEGAL_INSTR;
        exc_tval  = 32'h0000_0000;

        if (imem_fault) begin
            exc_cause = CAUSE_INSTR_ACCESS;
            exc_tval  = pc;
        end else if (illegal) begin
            exc_cause = CAUSE_ILLEGAL_INSTR;
            exc_tval  = instr;                  // the offending encoding
        end else if (ecall) begin
            exc_cause = CAUSE_ECALL_M;
        end else if (ebreak) begin
            exc_cause = CAUSE_BREAKPOINT;
            exc_tval  = pc;
        end else if (target_misaligned) begin
            exc_cause = CAUSE_INSTR_MISALIGNED;
            exc_tval  = jump_target;
        end else if (load_misaligned) begin
            exc_cause = CAUSE_LOAD_MISALIGNED;
            exc_tval  = alu_result;
        end else if (mem_read && dmem_fault) begin
            exc_cause = CAUSE_LOAD_ACCESS;
            exc_tval  = alu_result;
        end else if (store_misaligned) begin
            exc_cause = CAUSE_STORE_MISALIGNED;
            exc_tval  = alu_result;
        end else if (mem_write && dmem_fault) begin
            exc_cause = CAUSE_STORE_ACCESS;
            exc_tval  = alu_result;
        end else begin
            exception = 1'b0;
        end
    end

    assign commit = !halted && !exception;

    // Trap status registers: capture the first exception, then stay halted
    // until reset.
    always_ff @(posedge clk) begin
        if (reset) begin
            halted     <= 1'b0;
            trap_cause <= 4'd0;
            trap_pc    <= 32'h0000_0000;
            trap_tval  <= 32'h0000_0000;
        end else if (!halted && exception) begin
            halted     <= 1'b1;
            trap_cause <= exc_cause;
            trap_pc    <= pc;
            trap_tval  <= exc_tval;
        end
    end

endmodule
