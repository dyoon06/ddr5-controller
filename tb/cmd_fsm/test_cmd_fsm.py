import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge

tRCD = 16
tRC  = 46
CMD_NOP, CMD_ACT, CMD_RD, CMD_WR, CMD_PRE, CMD_REF = range(6)

async def reset(dut):
    dut.req_valid.value    = 0
    dut.req_is_write.value = 0
    dut.req_bank.value     = 0
    dut.req_row.value      = 0
    dut.req_col.value      = 0
    dut.rst_n.value        = 0
    for _ in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)

async def one_request(dut, is_write, bank, row, col):
    # FSM must be idle/ready before we hand it a request
    assert int(dut.req_ready.value) == 1, "FSM not ready in IDLE"
    dut.req_is_write.value = is_write
    dut.req_bank.value     = bank
    dut.req_row.value      = row
    dut.req_col.value      = col
    dut.req_valid.value    = 1

    # cycle 0: ACT issues on this edge
    await RisingEdge(dut.clk)
    dut.req_valid.value = 0
    await FallingEdge(dut.clk)
    assert int(dut.cmd.value) == CMD_ACT, "cycle 0 must be ACT"

    # the bus stays NOP for tRCD-1 cycles, then the column command appears at tRCD
    for i in range(1, tRCD):
        await RisingEdge(dut.clk); await FallingEdge(dut.clk)
        assert int(dut.cmd.value) == CMD_NOP, f"expected NOP at cycle {i}"
    await RisingEdge(dut.clk); await FallingEdge(dut.clk)   # cycle tRCD
    exp_col = CMD_WR if is_write else CMD_RD
    assert int(dut.cmd.value) == exp_col, f"column cmd wrong at tRCD"
    assert int(dut.cmd_row.value) == row, "row mismatch on column cmd"
    assert int(dut.cmd_col.value) == col, "col mismatch on column cmd"

    # bank must not free before the column cmd, and should free at tRC from ACT
    cyc = tRCD
    while int(dut.req_ready.value) == 0:
        await RisingEdge(dut.clk); await FallingEdge(dut.clk)
        cyc += 1
        assert cyc <= tRC + 2, "bank never returned to ready"
    assert cyc == tRC, f"bank should free at tRC={tRC}, got {cyc}"

@cocotb.test()
async def read_then_write(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    await one_request(dut, is_write=0, bank=5, row=0x1234, col=0x2AB)
    dut._log.info("read sequence OK: ACT, RD at tRCD, free at tRC")

    await one_request(dut, is_write=1, bank=5, row=0x0ABC, col=0x155)
    dut._log.info("write sequence OK: ACT, WR at tRCD, free at tRC")
