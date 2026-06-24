TOPLEVEL_LANG       = verilog
SIM                ?= verilator
VERILOG_SOURCES     = $(PWD)/../../rtl/ddr5_pkg.sv $(PWD)/../../rtl/scheduler.sv
TOPLEVEL            = scheduler
COCOTB_TEST_MODULES = test_scheduler
EXTRA_ARGS         += --trace
include $(shell cocotb-config --makefiles)/Makefile.sim
