TOPLEVEL_LANG       = verilog
SIM                ?= verilator
VERILOG_SOURCES     = $(PWD)/../../rtl/ddr5_pkg.sv $(PWD)/../../rtl/cmd_fsm.sv
TOPLEVEL            = cmd_fsm
COCOTB_TEST_MODULES = test_cmd_fsm
EXTRA_ARGS         += --trace
include $(shell cocotb-config --makefiles)/Makefile.sim
