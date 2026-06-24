package ddr5_pkg;
  // ---- Geometry ----
  localparam int BG_BITS  = 2;
  localparam int BA_BITS  = 2;
  localparam int COL_BITS = 10;
  localparam int ROW_BITS = 16;
  localparam int NUM_BG    = 1 << BG_BITS;
  localparam int NUM_BANK  = 1 << (BG_BITS + BA_BITS);
  localparam int ADDR_BITS = BG_BITS + BA_BITS + COL_BITS + ROW_BITS;

  // ---- Timing: DDR5-4800, command clock 2400 MHz, tCK ~= 0.417 ns. Cycle counts. ----
  localparam int tRCD = 40;   // 16.7 ns : ACT -> column
  localparam int tRP  = 40;   // 16.7 ns : precharge
  localparam int tRAS = 77;   // 32 ns   : min row-open before precharge
  localparam int tRC  = 117;  // tRAS + tRP : ACT -> ACT
  localparam int tRTP = 18;   // max(12 nCK, 7.5 ns) -> 7.5 ns dominates at 2400 MHz
  localparam int tWR  = 72;   // 30 ns   : write recovery
  localparam int CL   = 40;   // CAS latency
  localparam int tCWL = 38;   // ~ CL-2 : CAS write latency
  localparam int BL        = 16;
  localparam int BURST_CYC = BL / 2;   // 8 burst cycles for BL16

  // derived: column-command -> bank-idle, per direction
  localparam int RD_COL_TO_FREE = ((tRTP > (tRAS - tRCD)) ? tRTP : (tRAS - tRCD)) + tRP;
  localparam int WR_COL_TO_FREE = tCWL + BURST_CYC + tWR + tRP;

  localparam int TIMER_W = $clog2(WR_COL_TO_FREE + 1);  // widest (write) busy window

  // ---- Request transaction ----
  localparam int DATA_BITS = 64;
  localparam int ID_BITS   = 4;
  typedef struct packed {
    logic                 is_write;
    logic [ADDR_BITS-1:0] addr;
    logic [DATA_BITS-1:0] wdata;
    logic [ID_BITS-1:0]   id;
  } req_t;

  // ---- DRAM commands ----
  typedef enum logic [2:0] {
    CMD_NOP, CMD_ACT, CMD_RD, CMD_WR, CMD_PRE, CMD_REF
  } cmd_e;

  // ---- Per-bank state ----
  typedef enum logic [1:0] {
    BANK_IDLE, BANK_ACTIVATING, BANK_ACCESS, BANK_PRECHARGE
  } bank_phase_e;
  typedef struct packed {
    bank_phase_e         phase;
    logic [TIMER_W-1:0]  timer;
    logic [ROW_BITS-1:0] open_row;
  } bank_state_t;
endpackage
