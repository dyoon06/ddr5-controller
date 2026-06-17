module heartbeat (
    input  logic       clk,
    input  logic       rst_n,
    output logic [7:0] count
);
    always_ff @(posedge clk or negedge rst_n)
        if (!rst_n) count <= '0;
        else        count <= count + 8'd1;
endmodule
