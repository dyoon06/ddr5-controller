TOPLEVEL_LANG   = verilog
SIM            ?= verilator
VERILOG_SOURCES = $(PWD)/../rtl/heartbeat.sv
TOPLEVEL        = heartbeat
MODULE          = test_heartbeat
EXTRA_ARGS     += --trace
include $(shell cocotb-config --makefiles)/Makefile.sim
