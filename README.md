# DDR5 Memory Controller

A simplified DDR5 memory controller built and verified with a fully
open-source toolchain (Verilator, cocotb, GTKWave). Targets the command
scheduling and bank-timing core of the JEDEC JESD79-5C specification.

## Toolchain
- Verilator (RTL simulation)
- cocotb 2.0 (Python verification)
- GTKWave (waveform inspection)
- Yosys (synthesis sanity check)

## Layout
- rtl/      SystemVerilog source
- tb/       cocotb testbenches
- sva/      SystemVerilog assertions
- sim/      simulation configs
- scripts/  Python automation (sweeps, regression)
- syn/      synthesis scripts and reports
- docs/     diagrams, waveforms, writeups

## Reproduce
    python3 -m venv .venv && source .venv/bin/activate
    pip install -r requirements.txt
    cd tb && make
