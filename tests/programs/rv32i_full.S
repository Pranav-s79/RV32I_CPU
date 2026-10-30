# rv32i_full.S
# Self-checking program that exercises every RV32I instruction.
#
# Conventions:
#   gp (x3)  = current test number (non-zero)
#   t6 (x31) = expected value scratch
#   s0 (x8)  = data memory base 0x0001_0000
# Result:
#   pass -> a0 = 0,           then ECALL
#   fail -> a0 = test number, then ECALL
# The testbench also compares every retired instruction against the Python
# reference model, so a broken branch cannot fake a pass.

#define TEST(n)          li gp, n
#define CHECK(reg, val)  li t6, val; bne reg, t6, fail
#define ADDR(reg, sym)   lui reg, %hi(sym); addi reg, reg, %lo(sym)

    .section .text.init
    .globl _start
_start:
    li      s0, 0x10000

# ------------------------------------------------------------------
# LUI / AUIPC
# ------------------------------------------------------------------
    TEST(1)
    lui     t0, 0x12345
    CHECK(t0, 0x12345000)
    TEST(2)
    lui     t0, 0xFFFFF
    CHECK(t0, 0xFFFFF000)
    TEST(3)
auipc_0:
    auipc   t0, 0
    ADDR(t1, auipc_0)
    bne     t0, t1, fail
    TEST(4)
auipc_1:
    auipc   t0, 0x1
    ADDR(t1, auipc_1 + 0x1000)
    bne     t0, t1, fail

# ------------------------------------------------------------------
# R-type
# ------------------------------------------------------------------
    TEST(10)
    li      a1, 5
    li      a2, 3
    add     a3, a1, a2
    CHECK(a3, 8)
    TEST(11)
    li      a1, 0x7FFFFFFF
    li      a2, 1
    add     a3, a1, a2              # signed overflow wraps
    CHECK(a3, 0x80000000)
    TEST(12)
    li      a1, 3
    li      a2, 5
    sub     a3, a1, a2
    CHECK(a3, 0xFFFFFFFE)
    TEST(13)
    li      a1, 1
    li      a2, 31
    sll     a3, a1, a2
    CHECK(a3, 0x80000000)
    TEST(14)
    li      a2, 35                  # only rs2[4:0] = 3 is used
    sll     a3, a1, a2
    CHECK(a3, 8)
    TEST(15)
    li      a1, -1
    li      a2, 1
    slt     a3, a1, a2              # -1 < 1
    CHECK(a3, 1)
    slt     a3, a2, a1
    CHECK(a3, 0)
    TEST(16)
    sltu    a3, a2, a1              # 1 < 0xFFFFFFFF
    CHECK(a3, 1)
    sltu    a3, a1, a2
    CHECK(a3, 0)
    sltu    a3, zero, a2            # rd = (rs2 != 0)
    CHECK(a3, 1)
    TEST(17)
    li      a1, 0xF0F0F0F0
    li      a2, 0xFF00FF00
    xor     a3, a1, a2
    CHECK(a3, 0x0FF00FF0)
    or      a3, a1, a2
    CHECK(a3, 0xFFF0FFF0)
    and     a3, a1, a2
    CHECK(a3, 0xF000F000)
    TEST(18)
    li      a1, 0x80000000
    li      a2, 31
    srl     a3, a1, a2
    CHECK(a3, 1)
    li      a2, 4
    srl     a3, a1, a2
    CHECK(a3, 0x08000000)
    sra     a3, a1, a2
    CHECK(a3, 0xF8000000)
    sra     a3, a1, zero            # shift by 0
    CHECK(a3, 0x80000000)
    TEST(19)
    li      a1, 7
    add     a1, a1, a1              # rd == rs1 == rs2
    CHECK(a1, 14)

# ------------------------------------------------------------------
# I-type arithmetic
# ------------------------------------------------------------------
    TEST(20)
    addi    a1, zero, -2048
    CHECK(a1, 0xFFFFF800)
    addi    a1, a1, 2047
    CHECK(a1, 0xFFFFFFFF)
    TEST(21)
    li      a1, -5
    slti    a3, a1, -4
    CHECK(a3, 1)
    slti    a3, a1, -5
    CHECK(a3, 0)
    TEST(22)
    li      a1, 5
    sltiu   a3, a1, -1              # imm sign-extends to 0xFFFFFFFF, compared unsigned
    CHECK(a3, 1)
    sltiu   a3, zero, 1             # seqz idiom
    CHECK(a3, 1)
    TEST(23)
    li      a1, 0x12345678
    xori    a3, a1, -1              # bitwise NOT
    CHECK(a3, 0xEDCBA987)
    ori     a3, a1, 0x0F0
    CHECK(a3, 0x123456F8)
    andi    a3, a1, 0x0FF
    CHECK(a3, 0x00000078)
    andi    a3, a1, -16             # imm = 0xFFFFFFF0
    CHECK(a3, 0x12345670)
    TEST(24)
    li      a1, 0x80000001
    slli    a3, a1, 31
    CHECK(a3, 0x80000000)
    srli    a3, a1, 31
    CHECK(a3, 1)
    srai    a3, a1, 31
    CHECK(a3, 0xFFFFFFFF)
    slli    a3, a1, 0
    CHECK(a3, 0x80000001)

# ------------------------------------------------------------------
# x0 is hardwired to zero
# ------------------------------------------------------------------
    TEST(30)
    addi    zero, zero, 5
    CHECK(zero, 0)
    lui     zero, 0x12345
    CHECK(zero, 0)
    li      t0, 0x5A5A5A5A
    sw      t0, 0(s0)
    lw      zero, 0(s0)             # load into x0 is discarded
    CHECK(zero, 0)

# ------------------------------------------------------------------
# Loads (word in memory: 0x8899AABB, little-endian)
# ------------------------------------------------------------------
    TEST(40)
    li      t0, 0x8899AABB
    sw      t0, 0(s0)
    lw      a1, 0(s0)
    CHECK(a1, 0x8899AABB)
    TEST(41)
    lb      a1, 0(s0)
    CHECK(a1, 0xFFFFFFBB)
    lb      a1, 1(s0)
    CHECK(a1, 0xFFFFFFAA)
    lb      a1, 2(s0)
    CHECK(a1, 0xFFFFFF99)
    lb      a1, 3(s0)
    CHECK(a1, 0xFFFFFF88)
    TEST(42)
    lbu     a1, 0(s0)
    CHECK(a1, 0xBB)
    lbu     a1, 3(s0)
    CHECK(a1, 0x88)
    TEST(43)
    lh      a1, 0(s0)
    CHECK(a1, 0xFFFFAABB)
    lh      a1, 2(s0)
    CHECK(a1, 0xFFFF8899)
    lhu     a1, 0(s0)
    CHECK(a1, 0xAABB)
    lhu     a1, 2(s0)
    CHECK(a1, 0x8899)
    TEST(44)
    li      t0, 0x00007F7F          # positive values must not sign-fill
    sw      t0, 4(s0)
    lb      a1, 4(s0)
    CHECK(a1, 0x7F)
    lh      a1, 4(s0)
    CHECK(a1, 0x7F7F)
    TEST(45)
    addi    t1, s0, 8
    lw      a1, -8(t1)              # negative offset
    CHECK(a1, 0x8899AABB)

# ------------------------------------------------------------------
# Stores
# ------------------------------------------------------------------
    TEST(50)
    sw      zero, 8(s0)
    li      t0, 0x11
    sb      t0, 8(s0)
    li      t0, 0x22
    sb      t0, 9(s0)
    li      t0, 0x33
    sb      t0, 10(s0)
    li      t0, 0x123456AB          # only the low byte is stored
    sb      t0, 11(s0)
    lw      a1, 8(s0)
    CHECK(a1, 0xAB332211)
    TEST(51)
    li      t0, 0xBEEF
    sh      t0, 12(s0)
    li      t0, 0x1234DEAD          # only the low halfword is stored
    sh      t0, 14(s0)
    lw      a1, 12(s0)
    CHECK(a1, 0xDEADBEEF)
    TEST(52)
    li      t0, 0xCAFEF00D
    addi    t1, s0, 32
    sw      t0, -16(t1)             # store with negative offset -> s0+16
    lw      a1, 16(s0)
    CHECK(a1, 0xCAFEF00D)
    TEST(53)
    li      t0, 0x77
    sb      t0, 17(s0)              # overwrite one byte inside a word
    lw      a1, 16(s0)
    CHECK(a1, 0xCAFE770D)
    TEST(54)
    li      t1, 0x10FFC             # last word of data memory
    li      t0, 0x600DF00D
    sw      t0, 0(t1)
    lw      a1, 0(t1)
    CHECK(a1, 0x600DF00D)

# ------------------------------------------------------------------
# Memory-mapped LED register
# ------------------------------------------------------------------
    TEST(60)
    li      t1, 0x80000000
    li      t0, 0xA
    sw      t0, 0(t1)
    lw      a1, 0(t1)
    CHECK(a1, 0xA)

# ------------------------------------------------------------------
# Branches: each condition taken and not taken
# ------------------------------------------------------------------
    TEST(70)
    li      a1, -1
    li      a2, 1
    beq     a1, a1, 1f
    j       fail
1:  beq     a1, a2, fail
    TEST(71)
    bne     a1, a2, 1f
    j       fail
1:  bne     a1, a1, fail
    TEST(72)
    blt     a1, a2, 1f              # -1 < 1 signed
    j       fail
1:  blt     a2, a1, fail
    blt     a1, a1, fail
    TEST(73)
    bge     a2, a1, 1f
    j       fail
1:  bge     a1, a1, 1f              # equal -> taken
    j       fail
1:  bge     a1, a2, fail
    TEST(74)
    bltu    a2, a1, 1f              # 1 < 0xFFFFFFFF unsigned
    j       fail
1:  bltu    a1, a2, fail
    bltu    a1, a1, fail
    TEST(75)
    bgeu    a1, a2, 1f
    j       fail
1:  bgeu    a1, a1, 1f
    j       fail
1:  bgeu    a2, a1, fail
    TEST(76)                        # backward branch: sum 10..1 = 55
    li      a1, 0
    li      a2, 10
2:  add     a1, a1, a2
    addi    a2, a2, -1
    bnez    a2, 2b
    CHECK(a1, 55)

# ------------------------------------------------------------------
# Jumps
# ------------------------------------------------------------------
    TEST(80)                        # JAL link = address of next instruction
    jal     ra, 1f
jal_ret:
    j       fail
1:  ADDR(t6, jal_ret)
    bne     ra, t6, fail
    TEST(81)                        # JALR target with bit 0 set: bit 0 is cleared
    ADDR(t0, jalr_target)
    addi    t0, t0, 1
    jalr    ra, 0(t0)
jalr_ret:
    j       fail
jalr_target:
    ADDR(t6, jalr_ret)
    bne     ra, t6, fail
    TEST(82)                        # JALR with rd == rs1: target uses OLD rs1
    ADDR(t0, jalr_same)
    jalr    t0, 0(t0)
jalr_same_ret:
    j       fail
jalr_same:
    ADDR(t6, jalr_same_ret)
    bne     t0, t6, fail
    TEST(83)                        # JALR with negative offset
    ADDR(t0, jalr_neg + 8)
    jalr    ra, -8(t0)
    j       fail
jalr_neg:
    TEST(84)                        # call / ret
    li      a0, 21
    call    double_it
    CHECK(a0, 42)
    TEST(85)                        # JAL to x0 does not link
    li      t0, 0x1234
    mv      ra, t0
    j       1f
    j       fail
1:  bne     ra, t0, fail

# ------------------------------------------------------------------
# FENCE: no observable effect in this in-order core
# ------------------------------------------------------------------
    TEST(90)
    li      t0, 0x5
    sw      t0, 20(s0)
    fence
    fence   rw, w
    lw      a1, 20(s0)
    CHECK(a1, 0x5)

# ------------------------------------------------------------------
# Done
# ------------------------------------------------------------------
pass:
    li      t1, 0x80000000
    li      t0, 0x5                 # LEDs = 0101 when the test passes
    sw      t0, 0(t1)
    li      a0, 0
    ecall

fail:
    mv      a0, gp
    ecall

double_it:
    add     a0, a0, a0
    ret
