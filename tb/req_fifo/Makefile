TOPLEVEL_LANG       = verilog
SIM                ?= verilator
VERILOG_SOURCES     = $(PWD)/../../rtl/ddr5_pkg.sv $(PWD)/../../rtl/req_fifo.sv
TOPLEVEL            = req_fifo
COCOTB_TEST_MODULES = test_req_fifo
EXTRA_ARGS         += --trace
include $(shell cocotb-config --makefiles)/Makefile.sim
