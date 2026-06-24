import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge

tRCD    = 40
tRC     = 117                          # read frees here (tRAS gates the read)
WR_FREE = 40 + (38 + 8 + 72 + 40)      # tRCD + tCWL + burst + tWR + tRP = 198
CMD_NOP, CMD_ACT, CMD_RD, CMD_WR, CMD_PRE, CMD_REF = range(6)

async def reset(dut):
    dut.req_valid.value = 0; dut.req_is_write.value = 0
    dut.req_bank.value = 0; dut.req_row.value = 0; dut.req_col.value = 0
    dut.rst_n.value = 0
    for _ in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk); await FallingEdge(dut.clk)

async def one_request(dut, is_write, bank, row, col):
    assert int(dut.req_ready.value) == 1, "FSM not ready in IDLE"
    dut.req_is_write.value = is_write
    dut.req_bank.value = bank; dut.req_row.value = row; dut.req_col.value = col
    dut.req_valid.value = 1
    await RisingEdge(dut.clk)
    dut.req_valid.value = 0
    await FallingEdge(dut.clk)
    assert int(dut.cmd.value) == CMD_ACT, "cycle 0 must be ACT"
    for i in range(1, tRCD):
        await RisingEdge(dut.clk); await FallingEdge(dut.clk)
        assert int(dut.cmd.value) == CMD_NOP, f"expected NOP at cycle {i}"
    await RisingEdge(dut.clk); await FallingEdge(dut.clk)   # cycle tRCD
    exp = CMD_WR if is_write else CMD_RD
    assert int(dut.cmd.value) == exp, "column cmd wrong at tRCD"
    assert int(dut.cmd_row.value) == row
    assert int(dut.cmd_col.value) == col
    cyc = tRCD
    while int(dut.req_ready.value) == 0:
        await RisingEdge(dut.clk); await FallingEdge(dut.clk)
        cyc += 1
        assert cyc <= WR_FREE + 4, "bank never returned to ready"
    return cyc

@cocotb.test()
async def read_then_write(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    rd_free = await one_request(dut, is_write=0, bank=5, row=0x1234, col=0x2AB)
    assert rd_free == tRC, f"read should free at tRC={tRC}, got {rd_free}"
    dut._log.info(f"read OK: RD at tRCD={tRCD}, frees at tRC={rd_free} (tRAS gates)")

    wr_free = await one_request(dut, is_write=1, bank=5, row=0x0ABC, col=0x155)
    assert wr_free == WR_FREE, f"write should free at {WR_FREE}, got {wr_free}"
    assert wr_free > rd_free, "write must free later than read (tWR recovery)"
    dut._log.info(f"write OK: WR at tRCD, frees at {wr_free} ({wr_free - rd_free} cycles past read, tWR penalty)")
