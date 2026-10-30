# SystemVerilog Guide (through this CPU's code)

Every example below is taken from `rtl/`. The aim is to connect each language feature to the circuit it creates.

## 1. Modules and ports

A module is a piece of hardware with pins. Instantiating it twice gives you two physical copies.

```systemverilog
module branch_unit
    import rv32i_pkg::*;          // use constants/types from the package
(
    input  logic        branch,
    input  logic [2:0]  funct3,
    input  logic [31:0] rs1_data,
    input  logic [31:0] rs2_data,
    output logic        taken
);
```

- `logic [31:0]` is a 32-wire bus. Bit 31 is the most significant.
- `input`/`output` are directions, like pins on a chip.
- In `rv32i_core.sv` each module is instantiated with named connections, `.port(signal)`, which is the same as wiring pins together.

```systemverilog
alu u_alu (
    .a      (alu_a),
    .b      (alu_b),
    .op     (alu_op),
    .result (alu_result)
);
```

**Parameters** are compile-time constants that make modules configurable:

```systemverilog
module instruction_memory #(parameter int WORDS = 1024, parameter INIT_FILE = "") (...)
```

## 2. Combinational vs. sequential logic

This is the most important idea in RTL.

| | Combinational | Sequential |
|-|---------------|------------|
| Output depends on | current inputs only | inputs **and stored state** |
| Changes | whenever inputs change | only at a clock edge |
| Hardware | gates, muxes, adders | flip-flops (registers) |
| SystemVerilog | `assign`, `always_comb` | `always_ff @(posedge clk)` |
| Assignment | blocking `=` | non-blocking `<=` |

**Combinational** example (`alu.sv`): a set of operators feeding a multiplexer.

```systemverilog
always_comb begin
    case (op)
        ALU_ADD: result = a + b;     // 32-bit adder
        ALU_SUB: result = a - b;     // subtractor (adder + inverter)
        ...
        default: result = 32'h0;
    endcase
end
```

**Sequential** example (`program_counter.sv`): 32 D flip-flops.

```systemverilog
always_ff @(posedge clk) begin
    if (reset)       pc <= RESET_VECTOR;
    else if (enable) pc <= next_pc;
end
```

The whole single-cycle CPU is: **flip-flops (PC, registers, memory) → a large combinational cloud → back into the same flip-flops.**

## 3. Clock edges and reset

- `@(posedge clk)` means "at the instant clk goes 0 → 1". Flip-flops sample their D input only at that instant.
- **Synchronous reset** (this project): reset is checked inside `always_ff @(posedge clk)`, so it only takes effect at a clock edge. It is simple, timing-friendly, and recommended for Xilinx FPGAs.
- An **asynchronous reset** would be written `always_ff @(posedge clk or posedge reset)` and act immediately. It is not used here.
- What reset touches in this CPU: the PC, the trap/halt registers, and the LED register. The register file and data memory are not reset (see `architecture.md` §6), which lets Vivado build them from LUT-RAM.

## 4. Blocking (`=`) vs. non-blocking (`<=`)

- **Non-blocking `<=`** in `always_ff`: all right-hand sides are evaluated first, then all registers update together. This models real flip-flops, which all sample at the same edge.
- **Blocking `=`** in `always_comb`: statements execute in order like software, and later lines see earlier results. This models wires flowing through gates.

Why it matters:

```systemverilog
// Two registers swapping values: correct with <=
always_ff @(posedge clk) begin
    a <= b;
    b <= a;      // uses the OLD a -> real swap
end
// With = this would set both to b's old value.
```

Rule used everywhere in this repo: `always_ff` uses only `<=`, `always_comb` uses only `=`.

## 5. Avoiding latches

If an `always_comb` block does not assign an output on some path, the hardware must "remember" the old value, which creates a **latch** (a level-sensitive memory). Latches are almost always bugs in FPGA designs.

`control_unit.sv` prevents this by assigning a default to **every** output at the top of the block:

```systemverilog
always_comb begin
    reg_write = 1'b0;     // defaults first
    mem_read  = 1'b0;
    ...
    case (opcode)
        OPC_LUI: begin reg_write = 1'b1; ... end
        ...
        default: illegal = 1'b1;
    endcase
end
```

Every `case` also has a `default`. Vivado reports latches; the Phase 1 baseline reports **0** (see `baseline.md`).

## 6. Register arrays (memories)

```systemverilog
logic [31:0] regs [0:31];   // 32 entries, each 32 bits wide
```

- `[31:0]` before the name is the **packed** width (bits of one entry).
- `[0:31]` after the name is the **unpacked** depth (number of entries).
- `regs[5]` is a 32-bit value; `regs[5][7:0]` is its low byte.

Read and write ports (`register_file.sv`):

```systemverilog
always_ff @(posedge clk)                      // write port: synchronous
    if (we && rd_addr != 5'd0) regs[rd_addr] <= rd_data;

assign rs1_data = (rs1_addr == 5'd0) ? 32'h0 : regs[rs1_addr];   // read port: combinational
```

A combinational read of an array becomes a big multiplexer, or LUT-RAM on Xilinx. A clocked read would be required for block RAM.

## 7. Bit slicing and concatenation

Slicing picks wires; it costs no logic.

```systemverilog
assign opcode = instr[6:0];
assign rd     = instr[11:7];
```

Concatenation `{}` and replication `{N{x}}` build buses from pieces. This is how the immediate generator works (`immediate_generator.sv`):

```systemverilog
// B-type: rebuild a 13-bit offset scattered across the instruction, then sign-extend
imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
//      ^^^^^^^^^^^^^^ 19 copies of the sign bit = sign extension
```

Indexed part-select for variable positions: `x[8*i +: 8]` means "8 bits starting at bit 8*i".

## 8. Signed vs. unsigned arithmetic

A 32-bit bus is just bits. Whether `0xFFFFFFFF` means 4,294,967,295 or −1 depends on how you compare it.

- `logic` values are **unsigned** by default.
- `$signed(x)` reinterprets the same bits as two's complement.

```systemverilog
ALU_SLT:  result = {31'b0, $signed(a) < $signed(b)};   // -1 < 1 -> 1
ALU_SLTU: result = {31'b0, a < b};                     // 0xFFFFFFFF < 1 -> 0
ALU_SRA:  result = $signed(a) >>> shamt;               // fills with the sign bit
ALU_SRL:  result = a >> shamt;                         // fills with zeros
```

- `>>>` is an arithmetic shift **only** when its operand is signed. `a >>> 4` on an unsigned `a` would shift in zeros, a classic bug.
- ADD and SUB give identical bits for signed and unsigned operands (that's the beauty of two's complement), so the ALU needs only one adder.
- Sign extension is done explicitly by replicating the top bit: `{{24{byte[7]}}, byte}` (see `load_store_unit.sv`).
- In Verilog, if any operand in an expression is unsigned, the whole expression becomes unsigned. Mixing `$signed` and unsigned values silently drops the signedness. Keep signed comparisons simple and isolated, as the ALU does.

## 9. Enums and packages

`rv32i_pkg.sv` defines shared types so the control unit and datapath agree on encodings:

```systemverilog
typedef enum logic [1:0] { WB_ALU = 2'd0, WB_MEM = 2'd1, WB_PC4 = 2'd2 } wb_sel_e;
```

An enum is just a bus with named values. It shows names in waveforms and catches some mismatches at compile time. It synthesizes to the same 2 wires as `logic [1:0]`.

## 10. How RTL maps to circuits

| RTL | Circuit |
|-----|---------|
| `assign y = a & b;` | AND gates (32 of them for 32-bit buses) |
| `a + b` | Adder; on Xilinx, LUTs plus the dedicated CARRY4 chain |
| `a < b` | Comparator (a subtractor's carry-out) |
| `cond ? x : y` / `case` | Multiplexer |
| `a << n` (variable n) | Barrel shifter: log2(32) = 5 layers of muxes |
| `always_ff @(posedge clk) q <= d;` | D flip-flop (FDRE on Xilinx) |
| `if (en) q <= d;` inside `always_ff` | Flip-flop with clock enable |
| array + combinational read | Mux tree or distributed RAM (LUTRAM) |
| array + clocked read | Block RAM (BRAM) |
| `x[7:0]`, `{a, b}` | Just wires: free |

The timing of the CPU is set by the longest chain of these between two flip-flops: the critical path (see `baseline.md`).

## 11. Simulation-only constructs

Testbenches (in `tb/`) use features that do not become hardware: `#1` delays, `initial` blocks with sequences, `$display`, `$fwrite`, `$urandom`, `$fatal`. In RTL, `initial` blocks are used only to set power-up contents of memories, which Vivado supports for FPGAs.
