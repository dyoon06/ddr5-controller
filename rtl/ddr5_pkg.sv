package ddr5_pkg;
  // Single sub-channel geometry (parameterizable).
  localparam int BG_BITS  = 2;   // 4 bank groups
  localparam int BA_BITS  = 2;   // 4 banks per group -> 16 banks
  localparam int COL_BITS = 10;  // 1024 columns per row
  localparam int ROW_BITS = 16;  // 65536 rows

  localparam int NUM_BG    = 1 << BG_BITS;             // 4
  localparam int NUM_BANK  = 1 << (BG_BITS + BA_BITS); // 16
  localparam int ADDR_BITS = BG_BITS + BA_BITS + COL_BITS + ROW_BITS; // 30
endpackage
