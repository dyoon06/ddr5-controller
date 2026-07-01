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
async def refresh_survives_sustained_traffic(dut):
    """Traffic never stops. The controller must still refresh: urgency has to
    drain the banks, fire the REFab, then let traffic resume. On a controller
    without an urgency mechanism this test fails (refresh starves forever)."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    # continuous cross-group demand: banks 0 (group 0) and 8 (group 2) re-consume
    # their level-driven requests forever, so the rank never goes idle on its own
    set_req(dut, {0: 0, 8: 0})

    horizon = 6 * REFI + RFC + 150
    ref_cyc = None
    acts_after_ref = 0
    for cyc in range(horizon):
        await FallingEdge(dut.clk)
        c = int(dut.cmd.value)
        if c == CMD_REF and ref_cyc is None:
            ref_cyc = cyc
        if ref_cyc is not None and c == CMD_ACT:
            acts_after_ref += 1
        await RisingEdge(dut.clk)

    assert ref_cyc is not None, \
        f"STARVATION: no REFab issued in {horizon} cycles of sustained traffic " \
        f"(refresh deadline was cycle {REFI}); the rank never drains"
    dut._log.info(f"REFab issued at cycle {ref_cyc} under sustained traffic (urgency drain works)")

    assert acts_after_ref > 0, "traffic never resumed after the refresh"
    assert int(dut.ref_overflow.value) == 0, "pending counter overflowed: refresh obligations were lost"
    dut._log.info(f"traffic resumed after refresh ({acts_after_ref} activates); no pending overflow")
