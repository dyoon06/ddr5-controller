TOPLEVEL_LANG       = verilog
SIM                ?= verilator
VERILOG_SOURCES     = $(PWD)/../../rtl/ddr5_pkg.sv $(PWD)/../../rtl/refresh_ctrl.sv
TOPLEVEL            = refresh_ctrl
COCOTB_TEST_MODULES = test_refresh
EXTRA_ARGS         += --trace -GREFI=40 -GRFC=12
include $(shell cocotb-config --makefiles)/Makefile.sim
