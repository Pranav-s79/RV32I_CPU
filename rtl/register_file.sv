`timescale 1ns/1ps
// register_file.sv
// 32 x 32-bit general-purpose registers (x0..x31).
//   - Two read ports, combinational (asynchronous): rs1_data, rs2_data
//   - One write port, synchronous: written at the rising clock edge
//   - x0 always reads 0 and ignores writes
//
// Read-during-write: in the cycle an instruction writes rd, the read ports
// still show the OLD value. The new value appears after the clock edge.
// That is exactly what a single-cycle CPU needs.
//
// Reset: the register contents are NOT cleared by 'reset' (the RISC-V spec
// leaves them undefined, and a reset port would stop Vivado from using
// LUT-RAM). They are initialized to 0 at FPGA configuration / sim start by
// the initial block, so simulation is deterministic.

module register_file (
    input  logic        clk,
    input  logic        we,         // write enable
    input  logic [4:0]  rs1_addr,
    input  logic [4:0]  rs2_addr,
    input  logic [4:0]  rd_addr,
    input  logic [31:0] rd_data,
    output logic [31:0] rs1_data,
    output logic [31:0] rs2_data
);

    logic [31:0] regs [0:31];

    initial begin
        for (int i = 0; i < 32; i++)
            regs[i] = 32'h0000_0000;
    end

    // Write port. The rd_addr != 0 check is what makes x0 read-only.
    always_ff @(posedge clk) begin
        if (we && (rd_addr != 5'd0))
            regs[rd_addr] <= rd_data;
    end

    // Read ports. The explicit x0 check means x0 reads 0 even if the
    // storage location somehow held something else.
    assign rs1_data = (rs1_addr == 5'd0) ? 32'h0000_0000 : regs[rs1_addr];
    assign rs2_data = (rs2_addr == 5'd0) ? 32'h0000_0000 : regs[rs2_addr];

endmodule
