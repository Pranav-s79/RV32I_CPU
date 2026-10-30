// tb_load_store_unit.sv
// Checks byte-lane placement for stores, extraction and sign/zero extension
// for loads, at every byte offset, plus misalignment detection.
// Memory word used for loads: 0x8899AABB, so lane 0 = BB, lane 3 = 88.
// Every byte has its top bit set, which makes sign extension visible.
`timescale 1ns/1ps
`include "tb_check.svh"

module tb_load_store_unit;
    import rv32i_pkg::*;

    int checks = 0;
    int errors = 0;

    logic        mem_read, mem_write;
    logic [2:0]  funct3;
    logic [31:0] addr, store_data, mem_rdata;
    logic [3:0]  wstrb;
    logic [31:0] mem_wdata, load_data;
    logic        load_misaligned, store_misaligned;

    load_store_unit dut (.*);

    task automatic do_load(logic [2:0] f3, logic [1:0] off, logic [31:0] exp_data, logic exp_mis, string label);
        mem_read = 1; mem_write = 0; funct3 = f3;
        addr = 32'h0001_0100 | off; mem_rdata = 32'h8899_AABB; store_data = 32'h0;
        #1;
        `CHECK({label, " misaligned flag"}, load_misaligned, exp_mis)
        `CHECK({label, " store flag stays 0"}, store_misaligned, 1'b0)
        `CHECK({label, " no write strobes"}, wstrb, 4'b0000)
        if (!exp_mis)
            `CHECK({label, " data"}, load_data, exp_data)
    endtask

    task automatic do_store(logic [2:0] f3, logic [1:0] off, logic [3:0] exp_strb, logic exp_mis, string label);
        logic [31:0] lane_mask;
        mem_read = 0; mem_write = 1; funct3 = f3;
        addr = 32'h0001_0100 | off; store_data = 32'h1234_5678; mem_rdata = 32'h0;
        #1;
        `CHECK({label, " misaligned flag"}, store_misaligned, exp_mis)
        if (!exp_mis) begin
            lane_mask = {{8{exp_strb[3]}}, {8{exp_strb[2]}}, {8{exp_strb[1]}}, {8{exp_strb[0]}}};
            `CHECK({label, " strobes"}, wstrb, exp_strb)
            // Only the strobed lanes matter. They must hold the low bytes of
            // rs2, shifted into place.
            case (f3)
                F3_B: `CHECK({label, " data in lanes"}, mem_wdata & lane_mask, (32'h78 << (8*off)) & lane_mask)
                F3_H: `CHECK({label, " data in lanes"}, mem_wdata & lane_mask, (32'h5678 << (8*off)) & lane_mask)
                default: `CHECK({label, " data in lanes"}, mem_wdata, 32'h1234_5678)
            endcase
        end
    endtask

    initial begin
        $dumpfile("build/sim/tb_load_store_unit.vcd");
        $dumpvars(0, tb_load_store_unit);

        // ---- Loads (word in memory = 0x8899AABB) ----
        do_load(F3_B,  2'd0, 32'hFFFF_FFBB, 0, "LB  off0");
        do_load(F3_B,  2'd1, 32'hFFFF_FFAA, 0, "LB  off1");
        do_load(F3_B,  2'd2, 32'hFFFF_FF99, 0, "LB  off2");
        do_load(F3_B,  2'd3, 32'hFFFF_FF88, 0, "LB  off3");
        do_load(F3_BU, 2'd0, 32'h0000_00BB, 0, "LBU off0");
        do_load(F3_BU, 2'd1, 32'h0000_00AA, 0, "LBU off1");
        do_load(F3_BU, 2'd2, 32'h0000_0099, 0, "LBU off2");
        do_load(F3_BU, 2'd3, 32'h0000_0088, 0, "LBU off3");
        do_load(F3_H,  2'd0, 32'hFFFF_AABB, 0, "LH  off0");
        do_load(F3_H,  2'd2, 32'hFFFF_8899, 0, "LH  off2");
        do_load(F3_H,  2'd1, 32'h0,         1, "LH  off1 misaligned");
        do_load(F3_H,  2'd3, 32'h0,         1, "LH  off3 misaligned");
        do_load(F3_HU, 2'd0, 32'h0000_AABB, 0, "LHU off0");
        do_load(F3_HU, 2'd2, 32'h0000_8899, 0, "LHU off2");
        do_load(F3_HU, 2'd1, 32'h0,         1, "LHU off1 misaligned");
        do_load(F3_W,  2'd0, 32'h8899_AABB, 0, "LW  off0");
        do_load(F3_W,  2'd1, 32'h0,         1, "LW  off1 misaligned");
        do_load(F3_W,  2'd2, 32'h0,         1, "LW  off2 misaligned");
        do_load(F3_W,  2'd3, 32'h0,         1, "LW  off3 misaligned");

        // Positive values must zero-fill even for signed loads
        mem_read = 1; mem_write = 0; funct3 = F3_B; addr = 32'h0001_0100; mem_rdata = 32'h0000_007F; #1;
        `CHECK("LB positive 0x7F", load_data, 32'h0000_007F)
        funct3 = F3_H; mem_rdata = 32'h0000_7FFF; #1;
        `CHECK("LH positive 0x7FFF", load_data, 32'h0000_7FFF)

        // ---- Stores (rs2 = 0x12345678) ----
        do_store(F3_B, 2'd0, 4'b0001, 0, "SB off0");
        do_store(F3_B, 2'd1, 4'b0010, 0, "SB off1");
        do_store(F3_B, 2'd2, 4'b0100, 0, "SB off2");
        do_store(F3_B, 2'd3, 4'b1000, 0, "SB off3");
        do_store(F3_H, 2'd0, 4'b0011, 0, "SH off0");
        do_store(F3_H, 2'd2, 4'b1100, 0, "SH off2");
        do_store(F3_H, 2'd1, 4'b0000, 1, "SH off1 misaligned");
        do_store(F3_H, 2'd3, 4'b0000, 1, "SH off3 misaligned");
        do_store(F3_W, 2'd0, 4'b1111, 0, "SW off0");
        do_store(F3_W, 2'd1, 4'b0000, 1, "SW off1 misaligned");
        do_store(F3_W, 2'd2, 4'b0000, 1, "SW off2 misaligned");
        do_store(F3_W, 2'd3, 4'b0000, 1, "SW off3 misaligned");

        // ---- Not a memory instruction: no flags, no strobes ----
        mem_read = 0; mem_write = 0; funct3 = F3_W; addr = 32'h0000_0003; #1;
        `CHECK("idle: no strobes", wstrb, 4'b0000)
        `CHECK("idle: no load misaligned", load_misaligned, 1'b0)
        `CHECK("idle: no store misaligned", store_misaligned, 1'b0)

        `TB_FINISH("tb_load_store_unit")
    end

endmodule
