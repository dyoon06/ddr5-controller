import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

REFI = 40   # overridden small for fast testing (real tREFI = 18720)
RFC  = 12   # overridden small for fast testing (real tRFC  = 708)

async def reset(dut):
    dut.rst_n.value = 0
    for _ in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test()
async def refresh_ctrl_checks(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    # --- scenario A: cadence + tRFC block while banks are idle ---
    dut.all_banks_idle.value = 1
    await reset(dut)
    t = 0
    while True:
        await RisingEdge(dut.clk)
        t += 1
        if int(dut.ref_issue.value) == 1:
            break
        assert t < REFI * 2, "refresh never issued while idle"
    dut._log.info(f"first REF issued at cycle {t} (REFI={REFI})")
    assert abs(t - REFI) <= 3, f"refresh should fire near tREFI={REFI}, fired at {t}"

    block = 0
    while True:
        await RisingEdge(dut.clk)
        if int(dut.ref_blocking.value) == 1:
            block += 1
        else:
            break
    dut._log.info(f"ref_blocking held {block} cycles after REF (RFC={RFC})")
    assert block == RFC - 1, f"bus should be blocked RFC-1={RFC - 1} cycles, got {block}"

    # --- scenario B: refresh postponed while banks busy, fires once idle ---
    dut.all_banks_idle.value = 0
    await reset(dut)
    fired = False
    for _ in range(REFI + 20):
        await RisingEdge(dut.clk)
        if int(dut.ref_issue.value) == 1:
            fired = True
    assert not fired, "refresh must not issue while banks are busy"
    pend = int(dut.ref_pending_cnt.value)
    assert pend >= 1, f"a refresh should be pending while busy, got {pend}"
    dut._log.info(f"refresh correctly held off while busy; pending={pend}")

    dut.all_banks_idle.value = 1
    issued = False
    for _ in range(10):
        await RisingEdge(dut.clk)
        if int(dut.ref_issue.value) == 1:
            issued = True
            break
    assert issued, "refresh should issue promptly once banks go idle"
    dut._log.info("refresh issued promptly after banks went idle")
