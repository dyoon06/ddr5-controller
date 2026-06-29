import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge

NUM_BANK = 16
REFI = 60   # overridden small for fast testing (real tREFI = 18720)
RFC  = 12   # overridden small for fast testing (real tRFC  = 708)
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

@cocotb.test()
async def refresh_on_shared_bus(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)   # all banks idle, no requests

    # 1) with the rank idle, a REFab appears on the shared command bus near tREFI
    ref_cyc = None
    for cyc in range(REFI + 30):
        await FallingEdge(dut.clk)
        if int(dut.cmd.value) == CMD_REF:
            ref_cyc = cyc
            break
        await RisingEdge(dut.clk)
    assert ref_cyc is not None, "no REFab issued on the bus while idle"
    dut._log.info(f"REFab issued on the shared bus at cycle {ref_cyc} (REFI={REFI})")
    assert abs(ref_cyc - REFI) <= 3, f"refresh should fire near tREFI={REFI}, got {ref_cyc}"

    # 2) request traffic right away; the tRFC block must stall it, then it resumes
    set_req(dut, {0: 0})   # bank 0 read
    act_cyc = None
    for k in range(RFC + 10):
        await RisingEdge(dut.clk)
        await FallingEdge(dut.clk)
        if int(dut.cmd.value) == CMD_ACT and int(dut.cmd_bank.value) == 0:
            act_cyc = k
            break
    assert act_cyc is not None, "bank 0 never activated after the refresh window"
    assert act_cyc >= RFC - 3, \
        f"bank 0 ACT should wait out the tRFC block (~{RFC}), but issued only +{act_cyc} after REF"
    dut._log.info(f"traffic stalled through tRFC; bank 0 ACT issued +{act_cyc} cycles after REFab")
    dut._log.info("refresh shares the bus and blocks commands for tRFC, then traffic resumes")
