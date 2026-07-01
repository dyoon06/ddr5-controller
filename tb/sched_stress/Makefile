TOPLEVEL_LANG       = verilog
SIM                ?= verilator
VERILOG_SOURCES     = $(PWD)/../../rtl/ddr5_pkg.sv $(PWD)/../../rtl/refresh_ctrl.sv $(PWD)/../../rtl/scheduler.sv
TOPLEVEL            = scheduler
COCOTB_TEST_MODULES = test_sched_stress
EXTRA_ARGS         += --trace -GREFI=60 -GRFC=12
include $(shell cocotb-config --makefiles)/Makefile.sim
