// tb_check.svh
// Shared check macros for self-checking testbenches.
// Each testbench declares:  int checks = 0; int errors = 0;
//
// `CHECK uses !== so X or Z values count as failures.

`ifndef TB_CHECK_SVH
`define TB_CHECK_SVH

`define CHECK(label, got, exp) \
    begin \
        checks++; \
        if ((got) !== (exp)) begin \
            errors++; \
            $display("FAIL: %s  got=0x%h  expected=0x%h  (t=%0t)", label, got, exp, $time); \
        end \
    end

`define TB_FINISH(tbname) \
    begin \
        if (errors == 0) begin \
            $display("PASS: %s (%0d checks)", tbname, checks); \
            $finish; \
        end else begin \
            $display("FAIL: %s (%0d of %0d checks failed)", tbname, errors, checks); \
            $fatal(1, "testbench failed"); \
        end \
    end

`endif
