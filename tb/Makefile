TOPLEVEL_LANG       = verilog
SIM                ?= verilator
VERILOG_SOURCES     = $(PWD)/../rtl/heartbeat.sv
TOPLEVEL            = heartbeat
COCOTB_TEST_MODULES = test_heartbeat
EXTRA_ARGS         += --trace
include $(shell cocotb-config --makefiles)/Makefile.sim
