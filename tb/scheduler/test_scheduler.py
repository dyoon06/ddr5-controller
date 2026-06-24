import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge

NUM_BANK = 16
tRCD   = 40
tRRD_S = 8
tCCD_S = 8
tCCD_L = 12
CMD_NOP, CMD_ACT, CMD_RD, CMD_WR, CMD_PRE, CMD_REF = range(6)

def set_req(dut, banks):
    rv = 0
    wv = 0
    for b, w in banks.items():
        rv |= (1 << b)
        if w:
            wv |= (1 << b)
    dut.req_valid.value = rv
    dut.req_is_write.value = wv

async def reset(dut):
    dut.req_valid.value = 0
    dut.req_is_write.value = 0
    dut.rst_n.value = 0
    for _ in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)

async def column_gap(dut, bank_a, bank_b, horizon=90):
    # reset, request reads on two banks, return {bank: cycle of its RD on the bus}
    await reset(dut)
    await RisingEdge(dut.clk)
    set_req(dut, {bank_a: 0, bank_b: 0})
    rd_cyc = {}
    for cyc in range(horizon):
        await FallingEdge(dut.clk)
        if int(dut.cmd.value) == CMD_RD:
            b = int(dut.cmd_bank.value)
            if b in (bank_a, bank_b) and b not in rd_cyc:
                rd_cyc[b] = cyc
        if bank_a in rd_cyc and bank_b in rd_cyc:
            break
        await RisingEdge(dut.clk)
    return rd_cyc

@cocotb.test()
async def scheduler_stage2(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    # --- scenario 1: fixed priority + parallel progress (activates now tRRD-spaced) ---
    await reset(dut)
    await RisingEdge(dut.clk)
    set_req(dut, {2: 0, 5: 0})
    await FallingEdge(dut.clk)
    assert int(dut.cmd.value) == CMD_ACT and int(dut.cmd_bank.value) == 2, \
        "bank 2 (lower index) should win the first ACT"
    saw_b5 = False
    for _ in range(tRRD_S + 6):
        await RisingEdge(dut.clk)
        await FallingEdge(dut.clk)
        if int(dut.cmd.value) == CMD_ACT and int(dut.cmd_bank.value) == 5:
            saw_b5 = True
    assert saw_b5, "bank 5 should activate after its tRRD spacing"
    busy = int(dut.bank_busy.value)
    assert (busy >> 2) & 1 and (busy >> 5) & 1, "both banks active in parallel"
    dut._log.info("arbitration + parallelism OK (bank 2 first, both active)")

    # --- scenario 2: same-group (tCCD_L) vs different-group (tCCD_S) column spacing ---
    same  = await column_gap(dut, 0, 1)   # banks 0,1 share bank group 0
    same_gap = same[1] - same[0]
    cross = await column_gap(dut, 0, 4)   # bank 0 in group 0, bank 4 in group 1
    cross_gap = cross[4] - cross[0]
    dut._log.info(f"same-group column gap = {same_gap} (tCCD_L), cross-group gap = {cross_gap} (tCCD_S)")

    assert same_gap == tCCD_L, f"same-group columns should be tCCD_L={tCCD_L} apart, got {same_gap}"
    assert cross_gap == tCCD_S, f"cross-group columns should be tCCD_S={tCCD_S} apart, got {cross_gap}"
    assert same_gap > cross_gap, "bank-group benefit: same-group spacing must exceed cross-group"
    dut._log.info("bank-group spacing OK: same-group columns wait longer than cross-group")
