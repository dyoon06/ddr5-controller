module scheduler
  import ddr5_pkg::*;
(
  input  logic                        clk,
  input  logic                        rst_n,
  // per-bank request interface (testbench drives these directly in stage one)
  input  logic [NUM_BANK-1:0]         req_valid,
  input  logic [NUM_BANK-1:0]         req_is_write,
  // shared command bus: one command per cycle
  output cmd_e                        cmd,
  output logic [$clog2(NUM_BANK)-1:0] cmd_bank,
  // visibility for the testbench
  output logic [NUM_BANK-1:0]         bank_busy
);
  localparam int BID_W = $clog2(NUM_BANK);

  // per-bank state
  bank_phase_e        phase      [NUM_BANK];
  logic [TIMER_W-1:0] timer      [NUM_BANK];
  logic               w_is_write [NUM_BANK];

  // per-bank request to the arbiter (what this bank wants to issue this cycle)
  cmd_e                want_cmd   [NUM_BANK];
  logic [NUM_BANK-1:0] want_valid;

  // ---- each bank decides what it wants this cycle (combinational) ----
  always_comb begin
    for (int b = 0; b < NUM_BANK; b++) begin
      want_cmd[b]   = CMD_NOP;
      want_valid[b] = 1'b0;
      case (phase[b])
        BANK_IDLE: if (req_valid[b]) begin
          want_cmd[b]   = CMD_ACT;                         // eligible to open a row
          want_valid[b] = 1'b1;
        end
        BANK_ACTIVATING: if (timer[b] == 0) begin
          want_cmd[b]   = w_is_write[b] ? CMD_WR : CMD_RD; // tRCD met: eligible for column cmd
          want_valid[b] = 1'b1;
        end
        default: ; // counting tRCD, or precharging: no bus request
      endcase
    end
  end

  // ---- arbiter: one grant per cycle, lowest bank index wins (fixed priority) ----
  logic             grant_valid;
  logic [BID_W-1:0] grant_bank;
  always_comb begin
    grant_valid = 1'b0;
    grant_bank  = '0;
    for (int b = NUM_BANK - 1; b >= 0; b--)   // scan high->low so lowest index wins the tie
      if (want_valid[b]) begin
        grant_valid = 1'b1;
        grant_bank  = BID_W'(b);
      end
  end

  // drive the shared bus from the grant
  assign cmd      = grant_valid ? want_cmd[grant_bank] : CMD_NOP;
  assign cmd_bank = grant_bank;

  genvar g;
  generate
    for (g = 0; g < NUM_BANK; g++)
      assign bank_busy[g] = (phase[g] != BANK_IDLE);
  endgenerate

  // ---- per-bank update: timers run independently; phase advances only on grant ----
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int b = 0; b < NUM_BANK; b++) begin
        phase[b]      <= BANK_IDLE;
        timer[b]      <= '0;
        w_is_write[b] <= 1'b0;
      end
    end else begin
      for (int b = 0; b < NUM_BANK; b++) begin
        case (phase[b])
          BANK_IDLE: if (grant_valid && grant_bank == BID_W'(b)) begin
            w_is_write[b] <= req_is_write[b];
            phase[b]      <= BANK_ACTIVATING;
            timer[b]      <= TIMER_W'(tRCD - 1);
          end
          BANK_ACTIVATING:
            if (grant_valid && grant_bank == BID_W'(b)) begin   // won the bus -> issue column
              phase[b] <= BANK_PRECHARGE;
              timer[b] <= w_is_write[b] ? TIMER_W'(WR_COL_TO_FREE - 1)
                                        : TIMER_W'(RD_COL_TO_FREE - 1);
            end else if (timer[b] != 0)                         // still counting tRCD
              timer[b] <= timer[b] - 1'b1;
            // (timer==0 and not granted = eligible-but-bus-blocked: hold and re-compete)
          BANK_PRECHARGE: if (timer[b] == 0) phase[b] <= BANK_IDLE;  // auto-precharge done, no bus
                          else timer[b] <= timer[b] - 1'b1;
          default: phase[b] <= BANK_IDLE;
        endcase
      end
    end
  end
endmodule
