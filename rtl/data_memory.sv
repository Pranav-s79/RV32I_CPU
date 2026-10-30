`timescale 1ns/1ps
// data_memory.sv
// Read/write data memory with byte write strobes.
//   - Read:  ASYNCHRONOUS (combinational). A load's data must arrive in the
//            same cycle as its address in a single-cycle CPU.
//   - Write: synchronous, at the rising clock edge, only the lanes whose
//            wstrb bit is 1.
//
// FPGA mapping: asynchronous read means Vivado builds this from LUT-RAM
// (distributed RAM), not block RAM. 1024 words x 32 bits uses roughly
// 4 KiB / 64 bits-per-LUT = 512 LUTs plus read muxes. Block RAM would
// need a pipeline stage (Phase 3+). See docs/architecture.md.
//
// Only address[INDEX_BITS+1:2] is used. The SoC decodes the upper bits and
// raises an access fault for addresses outside this memory, so accesses
// never alias.

module data_memory #(
    parameter int WORDS = 1024              // 1024 x 32 bit = 4 KiB
) (
    input  logic        clk,
    input  logic        we,
    input  logic [3:0]  wstrb,
    input  logic [31:0] address,            // byte address
    input  logic [31:0] wdata,
    output logic [31:0] rdata
);

    localparam int INDEX_BITS = $clog2(WORDS);

    logic [31:0]           mem [0:WORDS-1];
    logic [INDEX_BITS-1:0] index;
    logic [31:0]           byte_mask;
    logic [31:0]           merged;

    assign index = address[INDEX_BITS+1:2];

    initial begin
        for (int i = 0; i < WORDS; i++)
            mem[i] = 32'h0000_0000;
    end

    // Expand the 4 strobe bits into a 32-bit mask, then merge the new
    // bytes with the old word.
    assign byte_mask = {{8{wstrb[3]}}, {8{wstrb[2]}}, {8{wstrb[1]}}, {8{wstrb[0]}}};
    assign merged    = (wdata & byte_mask) | (mem[index] & ~byte_mask);

    always_ff @(posedge clk) begin
        if (we)
            mem[index] <= merged;
    end

    assign rdata = mem[index];

endmodule
