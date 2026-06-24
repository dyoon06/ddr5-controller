module cmd_fsm
  import ddr5_pkg::*;
(
  input  logic                       clk,
  input  logic                       rst_n,
  input  logic                       req_valid,
  input  logic                       req_is_write,
  input  logic [BG_BITS+BA_BITS-1:0] req_bank,
  input  logic [ROW_BITS-1:0]        req_row,
  input  logic [COL_BITS-1:0]        req_col,
  output logic                       req_ready,
  output cmd_e                       cmd,
  output logic [BG_BITS+BA_BITS-1:0] cmd_bank,
  output logic [ROW_BITS-1:0]        cmd_row,
  output logic [COL_BITS-1:0]        cmd_col
);
  bank_phase_e        phase;
  logic [TIMER_W-1:0] timer;
  logic                       w_is_write;
  logic [BG_BITS+BA_BITS-1:0] w_bank;
  logic [ROW_BITS-1:0]        w_row;
  logic [COL_BITS-1:0]        w_col;

  assign req_ready = (phase == BANK_IDLE);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      phase <= BANK_IDLE; timer <= '0; cmd <= CMD_NOP;
      cmd_bank <= '0; cmd_row <= '0; cmd_col <= '0;
      w_is_write <= 1'b0; w_bank <= '0; w_row <= '0; w_col <= '0;
    end else begin
      cmd <= CMD_NOP;
      case (phase)
        BANK_IDLE: if (req_valid) begin
          cmd <= CMD_ACT;
          cmd_bank <= req_bank; cmd_row <= req_row; cmd_col <= '0;
          w_is_write <= req_is_write;
          w_bank <= req_bank; w_row <= req_row; w_col <= req_col;
          phase <= BANK_ACTIVATING;
          timer <= TIMER_W'(tRCD - 1);          // ACT -> column gap = tRCD
        end
        BANK_ACTIVATING: if (timer == 0) begin
          cmd <= w_is_write ? CMD_WR : CMD_RD;  // column cmd, auto-precharge
          cmd_bank <= w_bank; cmd_row <= w_row; cmd_col <= w_col;
          phase <= BANK_PRECHARGE;
          // split: a write holds the bank far longer (tCWL + burst + tWR)
          timer <= w_is_write ? TIMER_W'(WR_COL_TO_FREE - 1)
                              : TIMER_W'(RD_COL_TO_FREE - 1);
        end else timer <= timer - 1'b1;
        BANK_PRECHARGE: if (timer == 0) phase <= BANK_IDLE;
                        else timer <= timer - 1'b1;
        default: phase <= BANK_IDLE;
      endcase
    end
  end
endmodule
