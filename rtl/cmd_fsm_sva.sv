// SVA timing checker for cmd_fsm. Bound onto the FSM, so no port changes.
module cmd_fsm_sva
  import ddr5_pkg::*;
(
  input logic clk,
  input logic rst_n,
  input cmd_e cmd
);
  // tRCD: every column command (RD/WR) must be preceded by an ACT exactly tRCD cycles earlier.
  // Checked from the column side with $past, which avoids Verilator's ## delay timing requirement.
  // $past depth tRCD builds delay registers; the TICKCOUNT warning is expected and harmless here.
  /* verilator lint_off TICKCOUNT */
  property p_trcd;
    @(posedge clk) disable iff (!rst_n)
      (cmd == CMD_RD || cmd == CMD_WR) |-> ($past(cmd, tRCD) == CMD_ACT);
  endproperty
  /* verilator lint_on TICKCOUNT */

  a_trcd: assert property (p_trcd)
    else $error("[SVA] tRCD violation: column command not %0d cycles after its ACT", tRCD);
endmodule

// inject the checker into every cmd_fsm instance
bind cmd_fsm cmd_fsm_sva u_sva (.clk(clk), .rst_n(rst_n), .cmd(cmd));
