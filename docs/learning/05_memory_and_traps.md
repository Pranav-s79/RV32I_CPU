# 05. Memory, Loads/Stores, and Traps

## Byte addresses and little-endian words

RISC-V addresses individual bytes. A 32-bit word occupies four consecutive
byte addresses. In little-endian order, the lowest address contains the least
significant byte. For a word `0x11223344` stored at address `A`:

| Address | Byte |
|---------|------|
| `A + 0` | `0x44` |
| `A + 1` | `0x33` |
| `A + 2` | `0x22` |
| `A + 3` | `0x11` |

The memory can still be organized as 32-bit words. Address bits `[1:0]` select
the byte lane within the word; higher address bits select the word.

## Store strobes and load formatting

The data port uses four write-strobe bits, one per byte lane. A word store
enables all lanes. A byte store enables one lane and shifts its value to that
lane. A halfword store enables two adjacent lanes. The load/store unit reverses
this process on reads: it shifts the selected lane down, then sign-extends or
zero-extends according to the instruction.

For a byte load from address offset 2, the selected value is `dmem_rdata[23:16]`.
`LB` replicates that byte's sign bit through bits `[31:8]`; `LBU` fills those
bits with zero. Similar rules apply to halfword loads.

## Alignment

An address is aligned for its access width when:

- byte access: any address;
- halfword access: address bit 0 is zero;
- word access: address bits `[1:0]` are zero.

This core traps on misaligned halfword and word accesses rather than splitting
them into multiple memory operations. This keeps the memory interface simple.

## Harvard memory map

The current system has separate instruction and data memories. The core's
instruction port reads the ROM; loads and stores use the data port. The SoC
decodes full addresses and reports faults for unmapped regions, preventing
small memories from silently aliasing large addresses.

| Address | Meaning |
|---------|---------|
| `0x0000_0000` onward | Instruction ROM |
| `0x0001_0000` onward | Data RAM |
| `0x8000_0000` | LED memory-mapped register |

Check [`rtl/rv32i_soc_top.sv`](../../rtl/rv32i_soc_top.sv) for exact configured
depths and address selection.

## Asynchronous reads and FPGA RAM

Phase 1 needs an instruction and load value within the same cycle, so its
memories use combinational reads and clocked writes. This generally maps to
LUT/distributed RAM rather than block RAM. BRAM typically has a registered
read; using it requires a pipeline or other latency handling. This is one
reason the memory interface must be decided carefully for Phase 2.

## Memory-mapped I/O

A peripheral can look like a memory address. A CPU store to an LED address
updates LEDs; a store to a UART transmit register could emit a character. The
CPU needs ordinary load/store instructions; address decoding in the SoC gives
the transaction its peripheral meaning. This is called memory-mapped I/O
(MMIO).

## Traps in this core

The current implementation has no CSRs or handler mode. On a fault, it halts
and exposes cause, PC, and trap value. The trapping instruction must not write
its destination or store to memory. Existing decisions and test cases define
the exact supported causes. A later pipeline must preserve in-order behavior:
older instructions may finish, the faulting instruction must not commit, and
younger wrong-path instructions must be discarded.

## Check your understanding

1. Which byte lane is selected by address offset 1?
2. Why does `SB` need a shifted `wdata` as well as a one-hot strobe?
3. What is the difference between an unmapped address fault and a misaligned
   address trap?
4. Why does registered-read BRAM affect the pipeline design?

## In this repository

Read [`../architecture.md`](../architecture.md) sections on the memory map,
exceptions, and asynchronous memories, then inspect
[`../../rtl/load_store_unit.sv`](../../rtl/load_store_unit.sv).
