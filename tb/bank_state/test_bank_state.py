import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

tRC = 46
BANK_IDLE, BANK_ACTIVATING = 0, 1

async def read_bank(dut, b):
    dut.dbg_bank.value = b
    await Timer(1, unit="ns")
    return int(dut.dbg_phase.value), int(dut.dbg_timer.value)

@cocotb.test()
async def reset_activate_countdown(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.act_valid.value = 0
    dut.act_bank.value  = 0
    dut.dbg_bank.value  = 0
    dut.rst_n.value     = 0
    for _ in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)

    # 1) reset clears all sampled banks
    for b in (0, 5, 15):
        phase, timer = await read_bank(dut, b)
        assert phase == BANK_IDLE and timer == 0, f"bank {b} not idle after reset"

    # 2) activate bank 5 for one cycle
    dut.act_bank.value  = 5
    dut.act_valid.value = 1
    await RisingEdge(dut.clk)
    dut.act_valid.value = 0
    await FallingEdge(dut.clk)
    phase, timer = await read_bank(dut, 5)
    assert phase == BANK_ACTIVATING, "bank 5 should be busy after activate"
    assert timer == tRC - 1, f"bank 5 timer should be tRC-1, got {timer}"

    # 3) neighbor untouched
    phase, timer = await read_bank(dut, 6)
    assert phase == BANK_IDLE and timer == 0, "bank 6 should be unaffected"

    # 4) run out the cycle; bank 5 returns to idle
    for _ in range(tRC):
        await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    phase, timer = await read_bank(dut, 5)
    assert phase == BANK_IDLE and timer == 0, f"bank 5 should reopen, got phase {phase} timer {timer}"

    dut._log.info("bank_state OK: reset, activate, tRC countdown, reopen")
