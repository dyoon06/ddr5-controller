import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge

CL = 8
CMD_NOP, CMD_ACT, CMD_RD, CMD_WR, CMD_PRE, CMD_REF = range(6)

def pattern(bank, row, col):
    return (row << 14) | (col << 4) | bank

@cocotb.test()
async def read_latency(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.cmd.value  = CMD_NOP
    dut.bank.value = 0
    dut.row.value  = 0
    dut.col.value  = 0
    dut.rst_n.value = 0
    for _ in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    assert int(dut.rdata_valid.value) == 0

    b, r, c = 5, 0x1234, 0x2AB
    dut.cmd.value  = CMD_RD
    dut.bank.value = b
    dut.row.value  = r
    dut.col.value  = c
    await RisingEdge(dut.clk)           # read command sampled (edge 0)
    dut.cmd.value = CMD_NOP

    for i in range(1, CL):              # must stay low for CL-1 cycles
        await RisingEdge(dut.clk)
        await FallingEdge(dut.clk)
        assert int(dut.rdata_valid.value) == 0, f"early valid at cycle {i}"

    await RisingEdge(dut.clk)           # edge CL
    await FallingEdge(dut.clk)
    assert int(dut.rdata_valid.value) == 1, "rdata_valid not high at CL"
    assert int(dut.rdata.value) == pattern(b, r, c), "rdata pattern mismatch"
    dut._log.info("dram_model OK: read data returned after CL cycles")
