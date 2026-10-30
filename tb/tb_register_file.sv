// tb_register_file.sv
// Checks: write/read of every register, x0 hardwired to zero, write enable,
// two independent read ports, read-during-write timing, random traffic
// compared against a simple array model.
`timescale 1ns/1ps
`include "tb_check.svh"

module tb_register_file;

    int checks = 0;
    int errors = 0;

    logic        clk = 0;
    logic        we;
    logic [4:0]  rs1_addr, rs2_addr, rd_addr;
    logic [31:0] rd_data, rs1_data, rs2_data;

    logic [31:0] model [0:31];

    register_file dut (.*);

    always #5 clk = ~clk;

    task automatic write_reg(input logic [4:0] r, input logic [31:0] v, input logic en);
        @(negedge clk);
        we = en; rd_addr = r; rd_data = v;
        @(posedge clk);
        #1;
        we = 0;
        if (en && r != 0) model[r] = v;
    endtask

    initial begin
        $dumpfile("build/sim/tb_register_file.vcd");
        $dumpvars(0, tb_register_file);

        we = 0; rd_addr = 0; rd_data = 0; rs1_addr = 0; rs2_addr = 0;
        for (int i = 0; i < 32; i++) model[i] = 32'h0;

        // 1. Initial contents are zero (deterministic start).
        for (int i = 0; i < 32; i++) begin
            rs1_addr = i[4:0]; #1;
            `CHECK("initial value is 0", rs1_data, 32'h0)
        end

        // 2. Write a unique pattern to every register, read back on both ports.
        for (int i = 1; i < 32; i++)
            write_reg(i[4:0], 32'hA5A5_0000 | i, 1'b1);
        for (int i = 0; i < 32; i++) begin
            rs1_addr = i[4:0];
            rs2_addr = 5'(31 - i);
            #1;
            `CHECK("rs1 port readback", rs1_data, model[i])
            `CHECK("rs2 port readback", rs2_data, model[31 - i])
        end

        // 3. x0 ignores writes and always reads zero.
        write_reg(5'd0, 32'hFFFF_FFFF, 1'b1);
        rs1_addr = 0; rs2_addr = 0; #1;
        `CHECK("x0 after write (rs1)", rs1_data, 32'h0)
        `CHECK("x0 after write (rs2)", rs2_data, 32'h0)
        // White-box: the write guard must also keep storage location 0 at
        // zero. (The read-side mux alone would hide a broken write guard.)
        `CHECK("x0 storage untouched", dut.regs[0], 32'h0)

        // 4. we = 0 blocks the write.
        write_reg(5'd7, 32'h1111_1111, 1'b0);
        rs1_addr = 7; #1;
        `CHECK("we=0 does not write", rs1_data, model[7])

        // 5. Read-during-write: old value before the edge, new value after.
        @(negedge clk);
        rs1_addr = 5'd9; we = 1; rd_addr = 5'd9; rd_data = 32'hCAFE_F00D;
        #1;
        `CHECK("read-during-write shows old value before edge", rs1_data, model[9])
        @(posedge clk); #1;
        we = 0; model[9] = 32'hCAFE_F00D;
        `CHECK("new value visible after edge", rs1_data, 32'hCAFE_F00D)

        // 6. Random writes and reads against the model.
        for (int n = 0; n < 1000; n++) begin
            write_reg($urandom_range(0, 31), $urandom, $urandom_range(0, 1));
            rs1_addr = $urandom_range(0, 31);
            rs2_addr = $urandom_range(0, 31);
            #1;
            `CHECK("random rs1", rs1_data, model[rs1_addr])
            `CHECK("random rs2", rs2_data, model[rs2_addr])
        end

        `TB_FINISH("tb_register_file")
    end

endmodule
