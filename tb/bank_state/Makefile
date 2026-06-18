TOPLEVEL_LANG       = verilog
SIM                ?= verilator
VERILOG_SOURCES     = $(PWD)/../../rtl/ddr5_pkg.sv $(PWD)/../../rtl/bank_state.sv
TOPLEVEL            = bank_state
COCOTB_TEST_MODULES = test_bank_state
EXTRA_ARGS         += --trace
include $(shell cocotb-config --makefiles)/Makefile.sim
