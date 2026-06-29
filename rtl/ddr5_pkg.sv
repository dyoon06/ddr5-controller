package ddr5_pkg;
  // ---- Geometry ----
  localparam int BG_BITS  = 2;
  localparam int BA_BITS  = 2;
  localparam int COL_BITS = 10;
  localparam int ROW_BITS = 16;
  localparam int NUM_BG    = 1 << BG_BITS;
  localparam int NUM_BANK  = 1 << (BG_BITS + BA_BITS);
  localparam int ADDR_BITS = BG_BITS + BA_BITS + COL_BITS + ROW_BITS;

  // ---- Intra-bank timing: DDR5-4800, command clock 2400 MHz, tCK ~= 0.417 ns. ----
  localparam int tRCD = 40;
  localparam int tRP  = 40;
  localparam int tRAS = 77;
  localparam int tRC  = 117;
  localparam int tRTP = 18;
  localparam int tWR  = 72;
  localparam int CL   = 40;
  localparam int tCWL = 38;
  localparam int BL        = 16;
  localparam int BURST_CYC = BL / 2;   // 8

  localparam int RD_COL_TO_FREE = ((tRTP > (tRAS - tRCD)) ? tRTP : (tRAS - tRCD)) + tRP;
  localparam int WR_COL_TO_FREE = tCWL + BURST_CYC + tWR + tRP;
  localparam int TIMER_W = $clog2(WR_COL_TO_FREE + 1);

  // ---- Bank-group inter-command timing ----
  // JEDEC DDR5-4800: tRRD_S = 8 nCK (~3.3 ns); tRRD_L = max(8 nCK, 5 ns) = 12 cycles
  // (5 ns = 12 tCK at 2400 MHz; some references round to 13). tCCD_S = BL/2 = 8.
  // tCCD_L (read, same group) is representative at 12; not yet pinned to exact JEDEC.
  localparam int tCCD_S = 8;
  localparam int tCCD_L = 12;
  localparam int tRRD_S = 8;
  localparam int tRRD_L = 12;
  localparam int BGT_W  = $clog2((tCCD_L > tRRD_L ? tCCD_L : tRRD_L) + 1);

  // ---- Rolling four-activate window ----
  // JEDEC DDR5-4800: tFAW = 32 nCK (1KB page) or 40 nCK (2KB page). Using 40 (>4*tRRD_S=32, binds).
  localparam int tFAW      = 40;
  localparam int FAW_DEPTH = 4;
  localparam int FAWT_W    = $clog2(tFAW + 1);

  // ---- Refresh: DDR5-4800, 16Gb device, normal all-bank (REFab) mode ----
  // tREFI = 7.8 us average interval = 18720 cycles at 2400 MHz.
  // tRFC1 (all-bank, 16Gb) = 295 ns = 708 cycles (8Gb ~195 ns, 24Gb ~410 ns; density-dependent).
  // FGR tRFC2 / same-bank tRFCsb exist (16Gb ~160 / ~130 ns) but are out of scope for this engine.
  localparam int tREFI = 18720;
  localparam int tRFC  = 708;

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
