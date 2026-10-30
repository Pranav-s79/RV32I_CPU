`timescale 1ns/1ps
// instruction_memory.sv
// Read-only instruction memory with an ASYNCHRONOUS (combinational) read.
//
// Started from the student's Phase 1 draft (a hard-coded case statement).
// Replaced the case statement with an array loaded from a hex file so any
// program can be run. The original draft is preserved in
// docs/phase_1/student_drafts/instruction_memory.sv.
//
// Why asynchronous: in a single-cycle CPU the instruction must appear in the
// SAME cycle its address (the PC) is presented. FPGA block RAM only has a
// registered (synchronous) read, which would add a cycle. So this memory
// synthesizes to LUTs (ROM / distributed RAM), not BRAM. See docs/architecture.md.
//
// Address handling: 'address' is a byte address. Instructions are 4 bytes,
// so the word index is address[INDEX_BITS+1:2]. Bits above the memory size
// are NOT checked here; the SoC raises an access fault for out-of-range PCs
// so a fetch can never silently wrap around (alias) to a lower address.

module instruction_memory #(
    parameter int    WORDS     = 1024,      // 1024 x 32 bit = 4 KiB
    parameter        INIT_FILE = ""         // hex file, one 32-bit word per line
) (
    input  logic [31:0] address,
    output logic [31:0] instruction
);

    localparam int INDEX_BITS = $clog2(WORDS);

    logic [31:0] mem [0:WORDS-1];

    // Fill with 0x00000000 first. That encoding is an illegal instruction, so
    // a program that runs off its end traps instead of executing garbage.
    initial begin
        for (int i = 0; i < WORDS; i++)
            mem[i] = 32'h0000_0000;
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, mem);
    end

    assign instruction = mem[address[INDEX_BITS+1:2]];

endmodule
