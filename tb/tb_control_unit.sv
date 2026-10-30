// tb_control_unit.sv
// Drives real instruction words (encoded by the GNU assembler) through
// instruction_decoder + control_unit and checks the control signals that
// matter for each instruction. Then checks that illegal encodings are
// flagged and cannot change state, and sweeps all 128 opcodes.
`timescale 1ns/1ps
`include "tb_check.svh"

module tb_control_unit;
    import rv32i_pkg::*;

    int checks = 0;
    int errors = 0;

    logic [31:0] instr;
    logic [6:0]  opcode, funct7;
    logic [4:0]  rd, rs1, rs2;
    logic [2:0]  funct3;
    logic [11:0] funct12;

    logic        reg_write, mem_read, mem_write, branch, jal, jalr, ecall, ebreak, illegal;
    alu_a_sel_e  alu_a_sel;
    alu_b_sel_e  alu_b_sel;
    alu_op_e     alu_op;
    imm_type_e   imm_type;
    wb_sel_e     wb_sel;

    instruction_decoder u_dec (.*);
    control_unit        dut   (.*);

    // State-changing outputs packed together: {reg_write, mem_read, mem_write, branch, jal, jalr}
    function automatic logic [5:0] effects();
        return {reg_write, mem_read, mem_write, branch, jal, jalr};
    endfunction

    task automatic apply(logic [31:0] ins);
        instr = ins;
        #1;
    endtask

    // ALU-type instruction (OP or OP-IMM)
    task automatic t_alu(logic [31:0] ins, alu_op_e op, alu_b_sel_e bsel, string label);
        apply(ins);
        `CHECK({label, " illegal"},   illegal,   1'b0)
        `CHECK({label, " effects"},   effects(), 6'b100000)
        `CHECK({label, " alu_op"},    alu_op,    op)
        `CHECK({label, " alu_a_sel"}, alu_a_sel, A_RS1)
        `CHECK({label, " alu_b_sel"}, alu_b_sel, bsel)
        `CHECK({label, " wb_sel"},    wb_sel,    WB_ALU)
        if (bsel == B_IMM) `CHECK({label, " imm_type"}, imm_type, IMM_I)
    endtask

    task automatic t_load(logic [31:0] ins, string label);
        apply(ins);
        `CHECK({label, " illegal"},  illegal,   1'b0)
        `CHECK({label, " effects"},  effects(), 6'b110000)
        `CHECK({label, " alu_op"},   alu_op,    ALU_ADD)
        `CHECK({label, " b_sel"},    alu_b_sel, B_IMM)
        `CHECK({label, " imm_type"}, imm_type,  IMM_I)
        `CHECK({label, " wb_sel"},   wb_sel,    WB_MEM)
    endtask

    task automatic t_store(logic [31:0] ins, string label);
        apply(ins);
        `CHECK({label, " illegal"},  illegal,   1'b0)
        `CHECK({label, " effects"},  effects(), 6'b001000)
        `CHECK({label, " alu_op"},   alu_op,    ALU_ADD)
        `CHECK({label, " b_sel"},    alu_b_sel, B_IMM)
        `CHECK({label, " imm_type"}, imm_type,  IMM_S)
    endtask

    task automatic t_branch(logic [31:0] ins, string label);
        apply(ins);
        `CHECK({label, " illegal"},  illegal,   1'b0)
        `CHECK({label, " effects"},  effects(), 6'b000100)
        `CHECK({label, " imm_type"}, imm_type,  IMM_B)
    endtask

    task automatic t_illegal(logic [31:0] ins, string label);
        apply(ins);
        `CHECK({label, " illegal"}, illegal,   1'b1)
        `CHECK({label, " no state change"}, effects(), 6'b000000)
        `CHECK({label, " not ecall"},  ecall,  1'b0)
        `CHECK({label, " not ebreak"}, ebreak, 1'b0)
    endtask

    initial begin
        // ---------------- R-type ----------------
        t_alu(32'h002081b3, ALU_ADD,  B_RS2, "add");
        t_alu(32'h402081b3, ALU_SUB,  B_RS2, "sub");
        t_alu(32'h002091b3, ALU_SLL,  B_RS2, "sll");
        t_alu(32'h0020a1b3, ALU_SLT,  B_RS2, "slt");
        t_alu(32'h0020b1b3, ALU_SLTU, B_RS2, "sltu");
        t_alu(32'h0020c1b3, ALU_XOR,  B_RS2, "xor");
        t_alu(32'h0020d1b3, ALU_SRL,  B_RS2, "srl");
        t_alu(32'h4020d1b3, ALU_SRA,  B_RS2, "sra");
        t_alu(32'h0020e1b3, ALU_OR,   B_RS2, "or");
        t_alu(32'h0020f1b3, ALU_AND,  B_RS2, "and");

        // ---------------- I-type arithmetic ----------------
        t_alu(32'hfff00093, ALU_ADD,  B_IMM, "addi");
        t_alu(32'h80012093, ALU_SLT,  B_IMM, "slti");
        t_alu(32'h7ff13093, ALU_SLTU, B_IMM, "sltiu");
        t_alu(32'h55514093, ALU_XOR,  B_IMM, "xori");
        t_alu(32'h00116093, ALU_OR,   B_IMM, "ori");
        t_alu(32'h0ff17093, ALU_AND,  B_IMM, "andi");
        t_alu(32'h01f11093, ALU_SLL,  B_IMM, "slli");
        t_alu(32'h00115093, ALU_SRL,  B_IMM, "srli");
        t_alu(32'h41f15093, ALU_SRA,  B_IMM, "srai");

        // ---------------- Loads ----------------
        t_load(32'hfff08283, "lb");
        t_load(32'h00209283, "lh");
        t_load(32'h0000a283, "lw");
        t_load(32'h7ff0c283, "lbu");
        t_load(32'h8000d283, "lhu");

        // ---------------- Stores ----------------
        t_store(32'hfe508fa3, "sb");
        t_store(32'h00509123, "sh");
        t_store(32'h0050a223, "sw");

        // ---------------- Branches ----------------
        t_branch(32'h00208463, "beq");
        t_branch(32'hfe209ee3, "bne");
        t_branch(32'h7e20cfe3, "blt");
        t_branch(32'h8020d063, "bge");
        t_branch(32'h0020e163, "bltu");
        t_branch(32'h0020f863, "bgeu");

        // ---------------- Jumps ----------------
        apply(32'h001000ef);                                  // jal ra, +2048
        `CHECK("jal effects",  effects(), 6'b100010)
        `CHECK("jal imm_type", imm_type,  IMM_J)
        `CHECK("jal wb_sel",   wb_sel,    WB_PC4)
        `CHECK("jal illegal",  illegal,   1'b0)

        apply(32'h000280e7);                                  // jalr ra, 0(t0)
        `CHECK("jalr effects",  effects(), 6'b100001)
        `CHECK("jalr imm_type", imm_type,  IMM_I)
        `CHECK("jalr alu",      alu_op,    ALU_ADD)
        `CHECK("jalr a_sel",    alu_a_sel, A_RS1)
        `CHECK("jalr b_sel",    alu_b_sel, B_IMM)
        `CHECK("jalr wb_sel",   wb_sel,    WB_PC4)
        `CHECK("jalr illegal",  illegal,   1'b0)

        // ---------------- Upper immediates ----------------
        apply(32'h123453b7);                                  // lui t2, 0x12345
        `CHECK("lui effects",  effects(), 6'b100000)
        `CHECK("lui a_sel",    alu_a_sel, A_ZERO)
        `CHECK("lui b_sel",    alu_b_sel, B_IMM)
        `CHECK("lui imm_type", imm_type,  IMM_U)
        `CHECK("lui alu",      alu_op,    ALU_ADD)
        `CHECK("lui wb",       wb_sel,    WB_ALU)

        apply(32'h80000397);                                  // auipc t2, 0x80000
        `CHECK("auipc effects",  effects(), 6'b100000)
        `CHECK("auipc a_sel",    alu_a_sel, A_PC)
        `CHECK("auipc b_sel",    alu_b_sel, B_IMM)
        `CHECK("auipc imm_type", imm_type,  IMM_U)
        `CHECK("auipc wb",       wb_sel,    WB_ALU)

        // ---------------- FENCE / ECALL / EBREAK ----------------
        apply(32'h0ff0000f);                                  // fence iorw, iorw
        `CHECK("fence legal",     illegal,   1'b0)
        `CHECK("fence no effect", effects(), 6'b000000)
        apply(32'h0310000f);                                  // fence rw, w
        `CHECK("fence rw,w legal", illegal,  1'b0)
        apply(32'h8330000f);                                  // fence.tso (fm=1000)
        `CHECK("fence.tso legal (treated as fence)", illegal, 1'b0)

        apply(32'h00000073);
        `CHECK("ecall flag",      ecall,     1'b1)
        `CHECK("ecall not ebreak", ebreak,   1'b0)
        `CHECK("ecall legal",     illegal,   1'b0)
        `CHECK("ecall no effect", effects(), 6'b000000)

        apply(32'h00100073);
        `CHECK("ebreak flag",      ebreak,    1'b1)
        `CHECK("ebreak not ecall", ecall,     1'b0)
        `CHECK("ebreak legal",     illegal,   1'b0)
        `CHECK("ebreak no effect", effects(), 6'b000000)

        // ---------------- Illegal encodings ----------------
        t_illegal(32'h0000_0000, "all zeros");
        t_illegal(32'hFFFF_FFFF, "all ones");
        t_illegal(32'h0000_4501, "compressed (c.li)");
        t_illegal(32'h0220_81b3, "mul (M extension)");
        t_illegal(32'h0220_c1b3, "div (M extension)");
        t_illegal(32'h4020_e1b3, "OP funct7=0100000 with OR");
        t_illegal(32'h0800_81b3, "OP funct7=0000100");
        t_illegal(32'h4011_1093, "slli with funct7=0100000");
        t_illegal(32'h0211_1093, "slli shamt[5]=1 (RV64 only)");
        t_illegal(32'h0211_5093, "srli shamt[5]=1");
        t_illegal(32'h2011_5093, "srli funct7=0010000");
        t_illegal(32'h0000_b283, "ld (RV64, load funct3=011)");
        t_illegal(32'h0000_e283, "load funct3=110 (lwu, RV64)");
        t_illegal(32'h0000_f283, "load funct3=111");
        t_illegal(32'h0050_b023, "sd (RV64, store funct3=011)");
        t_illegal(32'h0050_c023, "store funct3=100");
        t_illegal(32'h0020_a063, "branch funct3=010");
        t_illegal(32'h0020_b063, "branch funct3=011");
        t_illegal(32'h0002_90e7, "jalr funct3=001");
        t_illegal(32'h0000_100f, "fence.i (Zifencei)");
        t_illegal(32'h3000_2573, "csrrs a0, mstatus (Zicsr)");
        t_illegal(32'h3020_0073, "mret");
        t_illegal(32'h1050_0073, "wfi");
        t_illegal(32'h0000_80f3, "ecall with rs1!=0");
        t_illegal(32'h0000_00f3, "ecall with rd!=0");
        t_illegal(32'h0020_0073, "SYSTEM funct12=2");
        t_illegal(32'h0000_101b, "OP-IMM-32 (RV64 addiw)");
        t_illegal(32'h0000_0007, "FLW (F extension)");
        t_illegal(32'h0000_202f, "AMO (A extension)");

        // ---------------- Sweep every opcode ----------------
        // Only the 11 RV32I opcodes may ever decode as legal.
        for (int opc = 0; opc < 128; opc++) begin
            for (int k = 0; k < 64; k++) begin
                logic legal_opcode;
                apply({25'($urandom), 7'(opc)});
                legal_opcode = (opc == OPC_LUI)    || (opc == OPC_AUIPC)  || (opc == OPC_JAL)    ||
                               (opc == OPC_JALR)   || (opc == OPC_BRANCH) || (opc == OPC_LOAD)   ||
                               (opc == OPC_STORE)  || (opc == OPC_OP_IMM) || (opc == OPC_OP)     ||
                               (opc == OPC_MISC_MEM) || (opc == OPC_SYSTEM);
                if (!legal_opcode) begin
                    `CHECK("unknown opcode -> illegal", illegal, 1'b1)
                end
                // Whatever the encoding: illegal implies no side effects
                if (illegal)
                    `CHECK("illegal -> no state change", effects(), 6'b000000)
            end
        end

        `TB_FINISH("tb_control_unit")
    end

endmodule
