import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge

ADDR_BITS, DATA_BITS, ID_BITS = 30, 64, 4

def make_req(is_write, addr, wdata, rid):
    return (is_write << (ADDR_BITS + DATA_BITS + ID_BITS)) \
         | (addr     << (DATA_BITS + ID_BITS)) \
         | (wdata    << ID_BITS) | rid

@cocotb.test()
async def fifo_order(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.push.value = 0
    dut.pop.value  = 0
    dut.push_req.value = 0
    dut.rst_n.value = 0
    for _ in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    assert int(dut.empty.value) == 1 and int(dut.full.value) == 0

    reqs = [make_req(0, 0x10, 0xAAAA, 1),
            make_req(1, 0x20, 0xBBBB, 2),
            make_req(0, 0x30, 0xCCCC, 3)]

    for rq in reqs:
        dut.push_req.value = rq
        dut.push.value = 1
        await RisingEdge(dut.clk)
    dut.push.value = 0
    await FallingEdge(dut.clk)
    assert int(dut.empty.value) == 0

    for expected in reqs:
        assert int(dut.head_req.value) == expected, "FIFO order wrong"
        dut.pop.value = 1
        await RisingEdge(dut.clk)
        dut.pop.value = 0
        await FallingEdge(dut.clk)

    assert int(dut.empty.value) == 1, "FIFO should drain to empty"
    dut._log.info("req_fifo OK: order preserved, empty/full correct")
