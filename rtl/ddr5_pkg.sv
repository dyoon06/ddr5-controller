package ddr5_pkg;
  // ---- Single sub-channel geometry (parameterizable) ----
  localparam int BG_BITS  = 2;   // 4 bank groups
  localparam int BA_BITS  = 2;   // 4 banks per group -> 16 banks
  localparam int COL_BITS = 10;  // 1024 columns per row
  localparam int ROW_BITS = 16;  // 65536 rows

  localparam int NUM_BG    = 1 << BG_BITS;             // 4
  localparam int NUM_BANK  = 1 << (BG_BITS + BA_BITS); // 16
  localparam int ADDR_BITS = BG_BITS + BA_BITS + COL_BITS + ROW_BITS; // 30

  // ---- Timing (cycles). PLACEHOLDERS, set from JESD79-5C in Week 3. ----
  localparam int tRC  = 46;  // ACT-to-ACT, same bank
  localparam int tRCD = 16;  // ACT-to-column
  localparam int tRP  = 16;  // precharge

  localparam int TIMER_W = $clog2(tRC + 1);

  // ---- Per-bank state ----
  typedef enum logic [1:0] {
    BANK_IDLE,
    BANK_ACTIVATING,
    BANK_ACCESS,
    BANK_PRECHARGE
  } bank_phase_e;

  typedef struct packed {
    bank_phase_e         phase;
    logic [TIMER_W-1:0]  timer;     // cycles until next legal action
    logic [ROW_BITS-1:0] open_row;  // dormant under closed-page (open-page stretch)
  } bank_state_t;
endpackage
