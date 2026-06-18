module bank_state
  import ddr5_pkg::*;
(
  input  logic                       clk,
  input  logic                       rst_n,
  // thin activate interface (Week 2 FSM will drive this for real)
  input  logic                       act_valid,
  input  logic [BG_BITS+BA_BITS-1:0] act_bank,
  // debug read port for observability
  input  logic [BG_BITS+BA_BITS-1:0] dbg_bank,
  output bank_phase_e                dbg_phase,
  output logic [TIMER_W-1:0]         dbg_timer
);
  bank_state_t banks [NUM_BANK];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < NUM_BANK; i++) begin
        banks[i].phase    <= BANK_IDLE;
        banks[i].timer    <= '0;
        banks[i].open_row <= '0;
      end
    end else begin
      // tick: each busy bank counts down; at the last cycle it reopens
      for (int i = 0; i < NUM_BANK; i++) begin
        if (banks[i].timer != 0) begin
          banks[i].timer <= banks[i].timer - 1'b1;
          if (banks[i].timer == 1)
            banks[i].phase <= BANK_IDLE;
        end
      end
      // accept an ACTIVATE only on an idle bank (closed-page: load full tRC)
      if (act_valid && banks[act_bank].phase == BANK_IDLE) begin
        banks[act_bank].phase <= BANK_ACTIVATING;
        banks[act_bank].timer <= TIMER_W'(tRC - 1);
      end
    end
  end

  assign dbg_phase = banks[dbg_bank].phase;
  assign dbg_timer = banks[dbg_bank].timer;
endmodule
