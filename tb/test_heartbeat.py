import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge

@cocotb.test()
async def count_increments(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.rst_n.value = 0
    for _ in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await FallingEdge(dut.clk)
    prev = int(dut.count.value)
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    now = int(dut.count.value)
    assert now == ((prev + 1) & 0xFF), f"count stuck: {prev} -> {now}"
    dut._log.info(f"heartbeat ok: {prev} -> {now}")
