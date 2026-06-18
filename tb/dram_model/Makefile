TOPLEVEL_LANG       = verilog
SIM                ?= verilator
VERILOG_SOURCES     = $(PWD)/../../rtl/ddr5_pkg.sv $(PWD)/../../rtl/dram_model.sv
TOPLEVEL            = dram_model
COCOTB_TEST_MODULES = test_dram_model
EXTRA_ARGS         += --trace
include $(shell cocotb-config --makefiles)/Makefile.sim
