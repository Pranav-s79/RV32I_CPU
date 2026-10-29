module simple_adder_tb;

    logic [31:0] a;
    logic [31:0] b;
    logic [31:0] sum;

    simple_adder dut (
        .a(a),
        .b(b),
        .sum(sum)
    );

    initial begin
        a = 5;
        b = 3;

        #10;

        $display("a = %0d, b = %0d, sum = %0d", a, b, sum);

        $finish;
    end

endmodule