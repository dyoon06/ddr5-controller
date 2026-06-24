module scheduler
  import ddr5_pkg::*;
(
  input  logic                        clk,
  input  logic                        rst_n,
  input  logic [NUM_BANK-1:0]         req_valid,
  input  logic [NUM_BANK-1:0]         req_is_write,
  output cmd_e                        cmd,
  output logic [$clog2(NUM_BANK)-1:0] cmd_bank,
  output logic [NUM_BANK-1:0]         bank_busy
);
  localparam int BID_W  = $clog2(NUM_BANK);
  localparam int FAWI_W = $clog2(FAW_DEPTH);

  bank_phase_e        phase      [NUM_BANK];
  logic [TIMER_W-1:0] timer      [NUM_BANK];
  logic               w_is_write [NUM_BANK];

  // bank-group inter-command spacing timers
  logic [BGT_W-1:0] ccd_l [NUM_BG];
  logic [BGT_W-1:0] ccd_s;
  logic [BGT_W-1:0] rrd_l [NUM_BG];
  logic [BGT_W-1:0] rrd_s;

  // rolling four-activate window: FAW_DEPTH slots, each counts down tFAW after an ACT.
  // An ACT may issue only if at least one slot is free (zero), so at most FAW_DEPTH
  // activates can be "in flight" within any tFAW-cycle window.
  logic [FAWT_W-1:0] faw [FAW_DEPTH];
  logic              faw_ok;
  logic [FAWI_W-1:0] faw_free_idx;

  always_comb begin
    faw_ok = 1'b0;
    for (int i = 0; i < FAW_DEPTH; i++)
      if (faw[i] == 0) faw_ok = 1'b1;
  end
  always_comb begin
    faw_free_idx = '0;
    for (int i = FAW_DEPTH - 1; i >= 0; i--)
      if (faw[i] == 0) faw_free_idx = FAWI_W'(i);
  end

  cmd_e                want_cmd   [NUM_BANK];
  logic [NUM_BANK-1:0] want_valid;

  // each bank decides what it wants; ACT now also gated by the tFAW window
  always_comb begin
    for (int b = 0; b < NUM_BANK; b++) begin
      want_cmd[b]   = CMD_NOP;
      want_valid[b] = 1'b0;
      case (phase[b])
        BANK_IDLE:
          if (req_valid[b] && rrd_l[b >> BA_BITS] == 0 && rrd_s == 0 && faw_ok) begin
            want_cmd[b]   = CMD_ACT;
            want_valid[b] = 1'b1;
          end
        BANK_ACTIVATING:
          if (timer[b] == 0 && ccd_l[b >> BA_BITS] == 0 && ccd_s == 0) begin
            want_cmd[b]   = w_is_write[b] ? CMD_WR : CMD_RD;
            want_valid[b] = 1'b1;
          end
        default: ;
      endcase
    end
  end

  // arbiter: one grant per cycle, lowest bank index wins (fixed priority)
  logic             grant_valid;
  logic [BID_W-1:0] grant_bank;
  always_comb begin
    grant_valid = 1'b0;
    grant_bank  = '0;
    for (int b = NUM_BANK - 1; b >= 0; b--)
      if (want_valid[b]) begin
        grant_valid = 1'b1;
        grant_bank  = BID_W'(b);
      end
  end

  assign cmd      = grant_valid ? want_cmd[grant_bank] : CMD_NOP;
  assign cmd_bank = grant_bank;

  genvar g;
  generate
    for (g = 0; g < NUM_BANK; g++)
      assign bank_busy[g] = (phase[g] != BANK_IDLE);
  endgenerate

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int b = 0; b < NUM_BANK; b++) begin
        phase[b]      <= BANK_IDLE;
        timer[b]      <= '0;
        w_is_write[b] <= 1'b0;
      end
      for (int k = 0; k < NUM_BG; k++) begin
        ccd_l[k] <= '0;
        rrd_l[k] <= '0;
      end
      ccd_s <= '0;
      rrd_s <= '0;
      for (int j = 0; j < FAW_DEPTH; j++) faw[j] <= '0;
    end else begin
      // spacing timers and the tFAW slots tick down independently
      if (ccd_s != 0) ccd_s <= ccd_s - 1'b1;
      if (rrd_s != 0) rrd_s <= rrd_s - 1'b1;
      for (int k = 0; k < NUM_BG; k++) begin
        if (ccd_l[k] != 0) ccd_l[k] <= ccd_l[k] - 1'b1;
        if (rrd_l[k] != 0) rrd_l[k] <= rrd_l[k] - 1'b1;
      end
      for (int j = 0; j < FAW_DEPTH; j++)
        if (faw[j] != 0) faw[j] <= faw[j] - 1'b1;

      // on a grant, arm the spacing timers and (for an ACT) occupy a tFAW slot
      if (grant_valid) begin
        if (phase[grant_bank] == BANK_IDLE) begin                 // an ACT was granted
          rrd_l[grant_bank[BID_W-1 -: BG_BITS]] <= BGT_W'(tRRD_L - 1);
          rrd_s                                 <= BGT_W'(tRRD_S - 1);
          faw[faw_free_idx]                     <= FAWT_W'(tFAW - 1);
        end else if (phase[grant_bank] == BANK_ACTIVATING) begin  // a column was granted
          ccd_l[grant_bank[BID_W-1 -: BG_BITS]] <= BGT_W'(tCCD_L - 1);
          ccd_s                                 <= BGT_W'(tCCD_S - 1);
        end
      end

      // per-bank phase update (unchanged from stage one)
      for (int b = 0; b < NUM_BANK; b++) begin
        case (phase[b])
          BANK_IDLE: if (grant_valid && grant_bank == BID_W'(b)) begin
            w_is_write[b] <= req_is_write[b];
            phase[b]      <= BANK_ACTIVATING;
            timer[b]      <= TIMER_W'(tRCD - 1);
          end
          BANK_ACTIVATING:
            if (grant_valid && grant_bank == BID_W'(b)) begin
              phase[b] <= BANK_PRECHARGE;
              timer[b] <= w_is_write[b] ? TIMER_W'(WR_COL_TO_FREE - 1)
                                        : TIMER_W'(RD_COL_TO_FREE - 1);
            end else if (timer[b] != 0)
              timer[b] <= timer[b] - 1'b1;
          BANK_PRECHARGE: if (timer[b] == 0) phase[b] <= BANK_IDLE;
                          else timer[b] <= timer[b] - 1'b1;
          default: phase[b] <= BANK_IDLE;
        endcase
      end
    end
  end
endmodule
