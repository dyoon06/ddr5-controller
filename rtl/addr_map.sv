module addr_map
  import ddr5_pkg::*;
(
  input  logic [ADDR_BITS-1:0] phys_addr,
  output logic [BG_BITS-1:0]   bg,
  output logic [BA_BITS-1:0]   bank,
  output logic [COL_BITS-1:0]  col,
  output logic [ROW_BITS-1:0]  row
);
  // Layout LSB -> MSB: { row, col, bank, bg }
  // bg is lowest, so phys_addr+1 advances the bank group first: a
  // sequential stream sprays across all bank groups (tCCD_S spacing),
  // then banks, before any bank repeats. Maximises bank parallelism.
  localparam int BA_LO  = BG_BITS;
  localparam int COL_LO = BG_BITS + BA_BITS;
  localparam int ROW_LO = BG_BITS + BA_BITS + COL_BITS;

  assign bg   = phys_addr[BG_BITS-1   : 0];
  assign bank = phys_addr[COL_LO-1    : BA_LO];
  assign col  = phys_addr[ROW_LO-1    : COL_LO];
  assign row  = phys_addr[ADDR_BITS-1 : ROW_LO];
endmodule
