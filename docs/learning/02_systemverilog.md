# 02. SystemVerilog and Synthesis

## RTL describes hardware

SystemVerilog is both a hardware description language and a verification
language. Files under `rtl/` describe circuits that tools can synthesize.
Testbench files can use delays, file I/O, and other simulation-only features;
those constructs generally do not become FPGA hardware.

Useful RTL types in this project:

- `logic` describes a single bit or a packed vector.
- `logic [31:0]` is a 32-bit vector. Its signedness is unsigned unless declared
  or cast as signed.
- `enum` gives named values to control encodings.
- `parameter` allows a module's configuration, such as memory depth or reset
  vector, to be chosen at instantiation.
- An unpacked array such as `logic [31:0] mem [0:1023]` represents words in a
  memory-like structure.

## Assignments and procedural blocks

Use `assign` for a continuous connection or simple expression. Use
`always_comb` for combinational decisions and give every output a value on
every path through the block. If a combinational output is not assigned in
some path, synthesis may infer a latch, which stores a value unexpectedly.

Use `always_ff @(posedge clk)` for clocked state. Use nonblocking assignment
(`<=`) for state updates. It models all registers sampling the old state at
the same edge. Blocking assignment (`=`) is appropriate for temporary values
inside combinational blocks.

```systemverilog
always_comb begin
    result = 32'b0;          // default prevents accidental latch inference
    case (operation)
        OP_ADD: result = a + b;
        OP_SUB: result = a - b;
        default: result = 32'b0;
    endcase
end

always_ff @(posedge clk) begin
    if (reset)
        pc <= RESET_VECTOR;
    else
        pc <= next_pc;
end
```

## Width and signedness

SystemVerilog will extend, truncate, and compare vectors according to language
rules. Those rules can surprise you. For example, a signed comparison should
make signedness explicit: `$signed(a) < $signed(b)`. Unsigned `SLTU` must
compare raw bit patterns instead. Shift operations use only the low five bits
of a shift amount for a 32-bit RV32I operand.

Write explicit widths for constants when practical (`32'd4`, `32'b0`). Check
the width of concatenations and slices. An immediate with one missing sign bit
can break only negative offsets, so corner cases matter.

## Simulation is not synthesis

The simulator evaluates the RTL model. The synthesis tool maps synthesizable
constructs into LUTs, FFs, memories, and routing. A design can simulate but
fail synthesis if it uses unsupported constructs. It can also synthesize
successfully and still implement the wrong behavior; synthesis is not a
correctness proof.

`initial` blocks are useful in the repository's simulation memories and can
initialize FPGA memory contents in supported flows. Reset behavior and
power-up initialization are distinct. Follow the specific memory and device
requirements when changing this design.

## Common mistakes

- Leaving a combinational signal unassigned on a branch, inferring a latch.
- Mixing blocking and nonblocking assignments for clocked state.
- Assuming a vector is signed because its leftmost bit is 1.
- Comparing only the bottom bits when the ISA requires a full signed compare.
- Writing simulation delays into synthesizable CPU logic.
- Changing a module's port without updating all instantiations and tests.

## Check your understanding

1. Why is a default assignment at the top of `always_comb` useful?
2. What distinction does `<=` make in a clocked block?
3. Why can `32'hffff_ffff` mean `-1` in one operation and a large positive
   value in another?
4. Does a clean synthesis run prove that the CPU implements the ISA correctly?

## In this repository

Read [`../systemverilog_guide.md`](../systemverilog_guide.md), then inspect
[`../../rtl/control_unit.sv`](../../rtl/control_unit.sv) and
[`../../rtl/rv32i_pkg.sv`](../../rtl/rv32i_pkg.sv).
