TOPLEVEL_LANG       = verilog
SIM                ?= verilator
VERILOG_SOURCES     = $(PWD)/../../rtl/ddr5_pkg.sv $(PWD)/../../rtl/refresh_ctrl.sv $(PWD)/../../rtl/scheduler.sv $(PWD)/../../rtl/scheduler_sva.sv
TOPLEVEL            = scheduler
COCOTB_TEST_MODULES = test_scheduler
EXTRA_ARGS         += --trace --assert
include $(shell cocotb-config --makefiles)/Makefile.sim
