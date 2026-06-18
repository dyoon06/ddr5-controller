package ddr5_pkg;
  // ---- Geometry ----
  localparam int BG_BITS  = 2;
  localparam int BA_BITS  = 2;
  localparam int COL_BITS = 10;
  localparam int ROW_BITS = 16;
  localparam int NUM_BG    = 1 << BG_BITS;
  localparam int NUM_BANK  = 1 << (BG_BITS + BA_BITS);
  localparam int ADDR_BITS = BG_BITS + BA_BITS + COL_BITS + ROW_BITS;  // ---- Timing (cycles). PLACEHOLDERS, real values in Week 3. ----
  localparam int tRC  = 46;
  localparam int tRCD = 16;
  localparam int tRP  = 16;
  localparam int CL   = 8;   // CAS latency
  localparam int TIMER_W = $clog2(tRC + 1);  // ---- Request transaction ----
  localparam int DATA_BITS = 64;
  localparam int ID_BITS   = 4;
  typedef struct packed {
    logic                 is_write;
    logic [ADDR_BITS-1:0] addr;
    logic [DATA_BITS-1:0] wdata;
    logic [ID_BITS-1:0]   id;
  } req_t;  // ---- DRAM commands ----
  typedef enum logic [2:0] {
    CMD_NOP, CMD_ACT, CMD_RD, CMD_WR, CMD_PRE, CMD_REF
  } cmd_e;  // ---- Per-bank state ----
  typedef enum logic [1:0] {
    BANK_IDLE, BANK_ACTIVATING, BANK_ACCESS, BANK_PRECHARGE
  } bank_phase_e;
  typedef struct packed {
    bank_phase_e         phase;
    logic [TIMER_W-1:0]  timer;
    logic [ROW_BITS-1:0] open_row;
  } bank_state_t;
endpackage
