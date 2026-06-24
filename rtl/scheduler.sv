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
  localparam int BID_W = $clog2(NUM_BANK);

  bank_phase_e        phase      [NUM_BANK];
  logic [TIMER_W-1:0] timer      [NUM_BANK];
  logic               w_is_write [NUM_BANK];

  // bank-group inter-command spacing timers (the new stage-two state)
  logic [BGT_W-1:0] ccd_l [NUM_BG];   // column-to-column, same group  (per bank group)
  logic [BGT_W-1:0] ccd_s;            // column-to-column, any group   (global, short)
  logic [BGT_W-1:0] rrd_l [NUM_BG];   // act-to-act,       same group  (per bank group)
  logic [BGT_W-1:0] rrd_s;            // act-to-act,       any group   (global, short)

  cmd_e                want_cmd   [NUM_BANK];
  logic [NUM_BANK-1:0] want_valid;

  // each bank decides what it wants this cycle, now gated by bank-group spacing
  always_comb begin
    for (int b = 0; b < NUM_BANK; b++) begin
      want_cmd[b]   = CMD_NOP;
      want_valid[b] = 1'b0;
      case (phase[b])
        BANK_IDLE:
          if (req_valid[b] && rrd_l[b >> BA_BITS] == 0 && rrd_s == 0) begin
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
    end else begin
      // bank-group spacing timers tick down independently
      if (ccd_s != 0) ccd_s <= ccd_s - 1'b1;
      if (rrd_s != 0) rrd_s <= rrd_s - 1'b1;
      for (int k = 0; k < NUM_BG; k++) begin
        if (ccd_l[k] != 0) ccd_l[k] <= ccd_l[k] - 1'b1;
        if (rrd_l[k] != 0) rrd_l[k] <= rrd_l[k] - 1'b1;
      end

      // on a grant, arm the spacing timers for that command's bank group
      if (grant_valid) begin
        if (phase[grant_bank] == BANK_IDLE) begin                 // an ACT was granted
          rrd_l[grant_bank[BID_W-1 -: BG_BITS]] <= BGT_W'(tRRD_L - 1);
          rrd_s                        <= BGT_W'(tRRD_S - 1);
        end else if (phase[grant_bank] == BANK_ACTIVATING) begin  // a column was granted
          ccd_l[grant_bank[BID_W-1 -: BG_BITS]] <= BGT_W'(tCCD_L - 1);
          ccd_s                        <= BGT_W'(tCCD_S - 1);
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
