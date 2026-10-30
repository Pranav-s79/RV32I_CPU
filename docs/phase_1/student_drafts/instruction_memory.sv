
module instruction_memory (
    input  logic [31:0] address,
    output logic [31:0] instruction
);

    always_comb begin
        case (address)
            32'h00000000:
                instruction = 32'h002081B3;

            32'h00000004:
                instruction = 32'h00500213;

            default:
                instruction = 32'h00000013;
        endcase
    end

endmodule
