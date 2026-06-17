import cocotb
import random
from cocotb.triggers import Timer

BG_BITS, BA_BITS, COL_BITS, ROW_BITS = 2, 2, 10, 16

def decode(a):
    bg   =  a                                  & ((1 << BG_BITS) - 1)
    bank = (a >> BG_BITS)                       & ((1 << BA_BITS) - 1)
    col  = (a >> (BG_BITS + BA_BITS))           & ((1 << COL_BITS) - 1)
    row  = (a >> (BG_BITS + BA_BITS + COL_BITS)) & ((1 << ROW_BITS) - 1)
    return bg, bank, col, row

@cocotb.test()
async def addr_decode(dut):
    # interleaving: consecutive addresses hit consecutive bank groups
    for a in range(4):
        dut.phys_addr.value = a
        await Timer(1, unit="ns")
        assert int(dut.bg.value) == a,   f"addr {a}: bg should interleave"
        assert int(dut.bank.value) == 0, f"addr {a}: bank should not move yet"

    # random check against the reference decode
    width = BG_BITS + BA_BITS + COL_BITS + ROW_BITS
    for _ in range(200):
        a = random.randrange(0, 1 << width)
        dut.phys_addr.value = a
        await Timer(1, unit="ns")
        bg, bank, col, row = decode(a)
        assert int(dut.bg.value)   == bg
        assert int(dut.bank.value) == bank
        assert int(dut.col.value)  == col
        assert int(dut.row.value)  == row
    dut._log.info("addr_map decode OK (interleaving + 200 random)")
