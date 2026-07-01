// Bound-in timing checkers for the scheduler. Shadow-counter style: no ## delays
// and no $past, so Verilator needs only --assert (no --timing, no TICKCOUNT pragma).
// Gap counters reset to 1 on their event and saturate at all-ones, so the sampled
// value at an event edge equals the exact cycle distance to the previous event.
module scheduler_sva
  import ddr5_pkg::*;
(
  input logic                        clk,
  input logic                        rst_n,
  input cmd_e                        cmd,
  input logic [$clog2(NUM_BANK)-1:0] cmd_bank,
  input logic [NUM_BANK-1:0]         bank_busy,
  input logic                        ref_issue,
  input logic                        ref_blocking
);
  localparam int BID_W = $clog2(NUM_BANK);
  localparam int GW    = 16;

  wire is_act = (cmd == CMD_ACT);
  wire is_col = (cmd == CMD_RD) || (cmd == CMD_WR);
  wire [BG_BITS-1:0] bg = cmd_bank[BID_W-1 -: BG_BITS];

  logic [GW-1:0] act_gap, col_gap;            // since last ACT / column, any group
  logic [GW-1:0] act_gap_g [NUM_BG];          // since last ACT / column, per group
  logic [GW-1:0] col_gap_g [NUM_BG];

  logic [31:0] cyc;                            // free-running time for the tFAW window
  logic [31:0] t4 [4];                         // timestamps of the last four ACTs
  logic [2:0]  n_act;                          // saturates at 4

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      act_gap <= '1;
      col_gap <= '1;
      for (int k = 0; k < NUM_BG; k++) begin
        act_gap_g[k] <= '1;
        col_gap_g[k] <= '1;
      end
      cyc   <= '0;
      n_act <= '0;
      for (int i = 0; i < 4; i++) t4[i] <= '0;
    end else begin
      cyc     <= cyc + 1;
      act_gap <= is_act ? GW'(1) : ((act_gap == '1) ? act_gap : act_gap + 1'b1);
      col_gap <= is_col ? GW'(1) : ((col_gap == '1) ? col_gap : col_gap + 1'b1);
      for (int k = 0; k < NUM_BG; k++) begin
        act_gap_g[k] <= (is_act && bg == BG_BITS'(k)) ? GW'(1)
                        : ((act_gap_g[k] == '1) ? act_gap_g[k] : act_gap_g[k] + 1'b1);
        col_gap_g[k] <= (is_col && bg == BG_BITS'(k)) ? GW'(1)
                        : ((col_gap_g[k] == '1) ? col_gap_g[k] : col_gap_g[k] + 1'b1);
      end
      if (is_act) begin
        t4[3] <= t4[2];
        t4[2] <= t4[1];
        t4[1] <= t4[0];
        t4[0] <= cyc;
        if (n_act != 3'd4) n_act <= n_act + 1'b1;
      end
    end
  end

  a_rrd_s: assert property (@(posedge clk) disable iff (!rst_n)
             is_act |-> (act_gap >= GW'(tRRD_S)))
           else $error("[SVA] tRRD_S violation: ACT-to-ACT gap %0d < %0d", act_gap, tRRD_S);

  a_rrd_l: assert property (@(posedge clk) disable iff (!rst_n)
             is_act |-> (act_gap_g[bg] >= GW'(tRRD_L)))
           else $error("[SVA] tRRD_L violation: same-group ACT gap %0d < %0d", act_gap_g[bg], tRRD_L);

  a_ccd_s: assert property (@(posedge clk) disable iff (!rst_n)
             is_col |-> (col_gap >= GW'(tCCD_S)))
           else $error("[SVA] tCCD_S violation: column-to-column gap %0d < %0d", col_gap, tCCD_S);

  a_ccd_l: assert property (@(posedge clk) disable iff (!rst_n)
             is_col |-> (col_gap_g[bg] >= GW'(tCCD_L)))
           else $error("[SVA] tCCD_L violation: same-group column gap %0d < %0d", col_gap_g[bg], tCCD_L);

  a_faw:   assert property (@(posedge clk) disable iff (!rst_n)
             (is_act && n_act == 3'd4) |-> ((cyc - t4[3]) >= 32'(tFAW)))
           else $error("[SVA] tFAW violation: five activates within %0d cycles", tFAW);

  a_quiet: assert property (@(posedge clk) disable iff (!rst_n)
             ref_blocking |-> (cmd == CMD_NOP))
           else $error("[SVA] command issued inside the tRFC window");

  a_ref_idle: assert property (@(posedge clk) disable iff (!rst_n)
                (cmd == CMD_REF) |-> (ref_issue && (bank_busy == '0)))
              else $error("[SVA] REFab issued with open banks");
endmodule

bind scheduler scheduler_sva u_sched_sva (
  .clk          (clk),
  .rst_n        (rst_n),
  .cmd          (cmd),
  .cmd_bank     (cmd_bank),
  .bank_busy    (bank_busy),
  .ref_issue    (ref_issue),
  .ref_blocking (ref_blocking)
);
