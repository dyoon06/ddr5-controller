module req_fifo
  import ddr5_pkg::*;
#(
  parameter int DEPTH = 8
)(
input  logic clk,
  input  logic rst_n,
  input  logic push,
  input  req_t push_req,
  output logic full,
  input  logic pop,
  output req_t head_req,
  output logic empty
);
 localparam int               PTR_W    = $clog2(DEPTH);
  localparam logic [PTR_W:0]   DEPTH_C  = (PTR_W+1)'(DEPTH);
  localparam logic [PTR_W-1:0] LAST_IDX = PTR_W'(DEPTH-1);

  req_t             mem [DEPTH];
  logic [PTR_W-1:0] wptr, rptr;
  logic [PTR_W:0]   count;

  assign full     = (count == DEPTH_C);
  assign empty    = (count == '0);
  assign head_req = mem[rptr];
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wptr <= '0; rptr <= '0; count <= '0;
    end else begin
      if (push && !full) begin
        mem[wptr] <= push_req;
        wptr      <= (wptr == LAST_IDX) ? '0 : wptr + 1'b1;
      end
      if (pop && !empty)
        rptr <= (rptr == LAST_IDX) ? '0 : rptr + 1'b1;
      case ({push && !full, pop && !empty})
        2'b10:   count <= count + 1'b1;
        2'b01:   count <= count - 1'b1;
        default: count <= count;
      endcase
    end
  end
endmodule
