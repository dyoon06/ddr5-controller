module refresh_ctrl
  import ddr5_pkg::*;
#(
  parameter int REFI   = tREFI,   // average refresh interval, cycles (overridable for test)
  parameter int RFC    = tRFC,    // refresh cycle time, bus blocked, cycles
  parameter int URGENT = 2        // pending level at which refresh becomes urgent
)(
  input  logic       clk,
  input  logic       rst_n,
  input  logic       all_banks_idle,   // from scheduler: every bank precharged/idle
  output logic       ref_issue,        // 1-cycle pulse: issue a REFab now
  output logic       ref_blocking,     // high while the device is busy for tRFC
  output logic       ref_urgent,       // pending debt high: scheduler must drain banks
  output logic       ref_overflow,     // sticky: a tREFI expiry was lost at MAX_PENDING
  output logic [3:0] ref_pending_cnt   // outstanding (postponed) refreshes
);
  localparam int REFI_W = $clog2(REFI);
  localparam int RFC_W  = $clog2(RFC + 1);
  localparam logic [3:0] MAX_PENDING = 4'd8;   // JEDEC allows up to 8 postponed refreshes

  logic [REFI_W-1:0] refi_cnt;
  logic [RFC_W-1:0]  rfc_cnt;
  logic [3:0]        pending;
  logic              ovf;

  wire exp       = (refi_cnt == 0);                                    // tREFI interval elapsed
  wire can_issue = (pending != 0) && (rfc_cnt == 0) && all_banks_idle; // REFab needs all rows closed

  assign ref_issue       = can_issue;
  assign ref_blocking    = (rfc_cnt != 0);
  assign ref_urgent      = (pending >= 4'(URGENT));   // drain request to the scheduler
  assign ref_overflow    = ovf;
  assign ref_pending_cnt = pending;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      refi_cnt <= REFI_W'(REFI - 1);
      rfc_cnt  <= '0;
      pending  <= '0;
      ovf      <= 1'b0;
    end else begin
      // tREFI cadence: free-running countdown, reload on expiry (keeps the average interval)
      refi_cnt <= exp ? REFI_W'(REFI - 1) : (refi_cnt - 1'b1);

      // tRFC block countdown; issuing a refresh (re)loads it
      if (can_issue)         rfc_cnt <= RFC_W'(RFC - 1);
      else if (rfc_cnt != 0) rfc_cnt <= rfc_cnt - 1'b1;

      // pending: +1 on tREFI expiry, -1 on issue, net zero if both happen this cycle
      case ({exp, can_issue})
        2'b10: if (pending != MAX_PENDING) pending <= pending + 1'b1;
        2'b01: pending <= pending - 1'b1;
        default: ; // 2'b11 net zero, 2'b00 unchanged
      endcase

      // a refresh obligation arrived with the queue full and nothing issued: it is lost.
      // In a real device this is under-refresh (data loss); make it observable, not silent.
      if (exp && (pending == MAX_PENDING) && !can_issue) ovf <= 1'b1;
    end
  end
endmodule
