TOPLEVEL_LANG       = verilog
SIM                ?= verilator
VERILOG_SOURCES     = $(PWD)/../../rtl/ddr5_pkg.sv $(PWD)/../../rtl/addr_map.sv
TOPLEVEL            = addr_map
COCOTB_TEST_MODULES = test_addr_map
EXTRA_ARGS         += --trace
include $(shell cocotb-config --makefiles)/Makefile.sim
