/* Linker script for programs that run on rv32i_soc_top.
 * Matches the SoC memory map (rtl/rv32i_soc_top.sv):
 *   IMEM 0x0000_0000, 4 KiB : code
 *   DMEM 0x0001_0000, 4 KiB : data, stack
 * Only .text is loaded (into IMEM). There is no loader for DMEM yet, so
 * programs must not depend on initialized .data/.rodata. build_programs.py
 * fails if such sections are non-empty.
 */
OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
    IMEM (rx) : ORIGIN = 0x00000000, LENGTH = 4K
    DMEM (rw) : ORIGIN = 0x00010000, LENGTH = 4K
}

SECTIONS
{
    .text : {
        *(.text.init)
        *(.text*)
    } > IMEM

    .data : {
        *(.rodata*) *(.srodata*) *(.data*) *(.sdata*)
    } > DMEM

    .bss (NOLOAD) : {
        *(.bss*) *(.sbss*) *(COMMON)
    } > DMEM

    /DISCARD/ : { *(.comment) *(.riscv.attributes) *(.note*) }
}
