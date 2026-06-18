module dram_model
  import ddr5_pkg::*;
(
  input  logic                       clk,
  input  logic                       rst_n,
  input  cmd_e                       cmd,
  input  logic [BG_BITS+BA_BITS-1:0] bank,
  input  logic [ROW_BITS-1:0]        row,
  input  logic [COL_BITS-1:0]        col,
  output logic                       rdata_valid,
  output logic [DATA_BITS-1:0]       rdata
);
  function automatic logic [DATA_BITS-1:0] pattern(
      input logic [BG_BITS+BA_BITS-1:0] b,
      input logic [ROW_BITS-1:0]        r,
      input logic [COL_BITS-1:0]        c);
    pattern = {{(DATA_BITS-(BG_BITS+BA_BITS)-ROW_BITS-COL_BITS){1'b0}}, r, c, b};
  endfunction

  logic                 v [CL];
  logic [DATA_BITS-1:0] d [CL];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int k = 0; k < CL; k++) begin v[k] <= 1'b0; d[k] <= '0; end
      rdata_valid <= 1'b0;
      rdata       <= '0;
    end else begin
      v[0] <= (cmd == CMD_RD);
      d[0] <= pattern(bank, row, col);
      for (int k = 1; k < CL; k++) begin
        v[k] <= v[k-1];
        d[k] <= d[k-1];
      end
      rdata_valid <= v[CL-1];
      rdata       <= d[CL-1];
    end
  end
endmodule
