`timescale 1ns/1ps
// rv32i_soc_top.sv
// Minimal system around the core: instruction memory, data memory, one LED
// output register, and the address decoder that connects them.
//
// Memory map (byte addresses):
//   0x0000_0000 - 0x0000_0FFF  Instruction memory, 4 KiB (fetch only)
//   0x0001_0000 - 0x0001_0FFF  Data memory, 4 KiB (load/store)
//   0x8000_0000                LED register (bits [3:0]), read/write
//   anything else              access fault
//
// Instruction and data memories are separate (a "Harvard" arrangement):
// loads/stores cannot reach instruction memory, and fetches cannot reach
// data memory.

module rv32i_soc_top
    import rv32i_pkg::*;
#(
    parameter        IMEM_INIT  = "",       // hex program image
    parameter int    IMEM_WORDS = 1024,
    parameter int    DMEM_WORDS = 1024
) (
    input  logic       clk,
    input  logic       reset,
    output logic [3:0] led,
    output logic       halted,
    output logic [3:0] trap_cause
);

    localparam logic [31:0] IMEM_BASE = 32'h0000_0000;
    localparam logic [31:0] IMEM_END  = IMEM_BASE + IMEM_WORDS * 4;   // exclusive
    localparam logic [31:0] DMEM_BASE = 32'h0001_0000;
    localparam logic [31:0] DMEM_END  = DMEM_BASE + DMEM_WORDS * 4;   // exclusive
    localparam logic [31:0] LED_ADDR  = 32'h8000_0000;

    logic [31:0] imem_addr, imem_rdata;
    logic        imem_fault;
    logic [31:0] dmem_addr, dmem_wdata, dmem_rdata, ram_rdata;
    logic [3:0]  dmem_wstrb;
    logic        dmem_re, dmem_we, dmem_fault;
    logic        ram_sel, led_sel;
    logic [3:0]  led_reg;
    logic [31:0] trap_pc, trap_tval;

    rv32i_core #(.RESET_VECTOR(IMEM_BASE)) u_core (
        .clk        (clk),
        .reset      (reset),
        .imem_addr  (imem_addr),
        .imem_rdata (imem_rdata),
        .imem_fault (imem_fault),
        .dmem_addr  (dmem_addr),
        .dmem_re    (dmem_re),
        .dmem_we    (dmem_we),
        .dmem_wstrb (dmem_wstrb),
        .dmem_wdata (dmem_wdata),
        .dmem_rdata (dmem_rdata),
        .dmem_fault (dmem_fault),
        .halted     (halted),
        .trap_cause (trap_cause),
        .trap_pc    (trap_pc),
        .trap_tval  (trap_tval)
    );

    // ---------------- Instruction side ----------------
    assign imem_fault = (imem_addr < IMEM_BASE) || (imem_addr >= IMEM_END);

    instruction_memory #(
        .WORDS     (IMEM_WORDS),
        .INIT_FILE (IMEM_INIT)
    ) u_imem (
        .address     (imem_addr),
        .instruction (imem_rdata)
    );

    // ---------------- Data side ----------------
    assign ram_sel    = (dmem_addr >= DMEM_BASE) && (dmem_addr < DMEM_END);
    assign led_sel    = (dmem_addr[31:2] == LED_ADDR[31:2]);
    assign dmem_fault = !(ram_sel || led_sel);

    data_memory #(.WORDS(DMEM_WORDS)) u_dmem (
        .clk     (clk),
        .we      (dmem_we && ram_sel),
        .wstrb   (dmem_wstrb),
        .address (dmem_addr),
        .wdata   (dmem_wdata),
        .rdata   (ram_rdata)
    );

    // LED register: a store with lane 0 enabled updates the 4 LEDs.
    always_ff @(posedge clk) begin
        if (reset)
            led_reg <= 4'b0000;
        else if (dmem_we && led_sel && dmem_wstrb[0])
            led_reg <= dmem_wdata[3:0];
    end

    assign led = led_reg;

    always_comb begin
        if (ram_sel)
            dmem_rdata = ram_rdata;
        else if (led_sel)
            dmem_rdata = {28'b0, led_reg};
        else
            dmem_rdata = 32'h0000_0000;
    end

endmodule
