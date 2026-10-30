
module program_counter (
    input  logic        clk,
    input  logic        reset,
    output logic [31:0] pc
);

    always_ff @(posedge clk) begin
        if (reset)
            pc <= 32'd0;
        else
            pc <= pc + 32'd4;
    end

endmodule
