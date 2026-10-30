`timescale 1ns/1ps
// load_store_unit.sv
// Byte-lane logic between the core and a 32-bit-wide data memory.
//
// Memory is organized as 32-bit words. Byte addresses map to lanes in
// little-endian order: the byte at address A lives in lane A[1:0] of word
// A[31:2]:
//
//   word bits:  [31:24]  [23:16]  [15:8]  [7:0]
//   lane:          3        2        1       0
//
// Stores: the store data is copied into every lane it could land in, and
//         a 4-bit write strobe selects which lanes actually get written.
// Loads:  the whole word is read, shifted so the wanted byte/halfword sits
//         at bit 0, then sign- or zero-extended to 32 bits.
//
// Alignment: LH/LHU/SH need addr[0] = 0; LW/SW need addr[1:0] = 00.
// This core does not support misaligned access; it reports it, and the
// core raises a misaligned-address exception instead of accessing memory.

module load_store_unit
    import rv32i_pkg::*;
(
    input  logic        mem_read,
    input  logic        mem_write,
    input  logic [2:0]  funct3,         // access width and signedness
    input  logic [31:0] addr,           // byte address from the ALU
    input  logic [31:0] store_data,     // rs2
    input  logic [31:0] mem_rdata,      // whole word read from memory

    output logic [3:0]  wstrb,          // byte lanes to write
    output logic [31:0] mem_wdata,      // store data, placed in its lanes
    output logic [31:0] load_data,      // extended load result for rd
    output logic        load_misaligned,
    output logic        store_misaligned
);

    logic [1:0]  offset;
    logic        misaligned;
    logic [31:0] shifted;

    assign offset = addr[1:0];

    // funct3[1:0]: 00 = byte, 01 = halfword, 10 = word
    always_comb begin
        case (funct3[1:0])
            2'b00:   misaligned = 1'b0;
            2'b01:   misaligned = offset[0];
            default: misaligned = (offset != 2'b00);
        endcase
    end

    assign load_misaligned  = mem_read  && misaligned;
    assign store_misaligned = mem_write && misaligned;

    // ---------------- Stores ----------------
    always_comb begin
        case (funct3[1:0])
            2'b00: begin                                    // SB
                mem_wdata = {4{store_data[7:0]}};
                wstrb     = 4'b0001 << offset;
            end
            2'b01: begin                                    // SH
                mem_wdata = {2{store_data[15:0]}};
                wstrb     = 4'b0011 << offset;
            end
            default: begin                                  // SW
                mem_wdata = store_data;
                wstrb     = 4'b1111;
            end
        endcase
        if (!mem_write)
            wstrb = 4'b0000;
    end

    // ---------------- Loads ----------------
    // Shift right by 0, 8, 16 or 24 bits so the addressed byte is in [7:0].
    assign shifted = mem_rdata >> {offset, 3'b000};

    always_comb begin
        case (funct3)
            F3_B:    load_data = {{24{shifted[7]}},  shifted[7:0]};    // sign-extend
            F3_BU:   load_data = {24'b0,             shifted[7:0]};    // zero-extend
            F3_H:    load_data = {{16{shifted[15]}}, shifted[15:0]};
            F3_HU:   load_data = {16'b0,             shifted[15:0]};
            default: load_data = mem_rdata;                            // LW
        endcase
    end

endmodule
