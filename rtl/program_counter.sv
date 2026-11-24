`timescale 1ns/1ps
// program_counter.sv
// The PC register: a 32-bit flip-flop bank holding the address of the
// instruction being executed this cycle.
//
// Circuit: 32 D flip-flops with synchronous reset and a clock enable.
//   - reset  = 1 at a rising clock edge -> pc becomes RESET_VECTOR
//   - enable = 1 at a rising clock edge -> pc becomes next_pc
//   - enable = 0                        -> pc holds its value

module program_counter #(
    parameter logic [31:0] RESET_VECTOR = 32'h0000_0000
) (
    input  logic        clk,
    input  logic        reset,      // synchronous, active high
    input  logic        enable,     // update PC this cycle
    input  logic [31:0] next_pc,    // chosen by next_pc_logic
    output logic [31:0] pc
);

    always_ff @(posedge clk) begin
        if (reset)
            pc <= RESET_VECTOR;
        else if (enable)
            pc <= next_pc;
    end

endmodule
