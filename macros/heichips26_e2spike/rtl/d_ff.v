module d_ff #(
    parameter integer w_WIDTH = 8
) (
    input  wire               clk,
    input  wire               rst,
    input  wire [w_WIDTH-1:0] d,
    output reg  [w_WIDTH-1:0] q
);

    always @(posedge clk or posedge rst) begin
        if (rst)
            q <= {w_WIDTH{1'b0}};
        else
            q <= d;
    end

endmodule
