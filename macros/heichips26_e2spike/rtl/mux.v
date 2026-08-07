module mux #(
    parameter integer w_WIDTH = 8
) (
    input  wire [w_WIDTH-1:0] a,
    input  wire [w_WIDTH-1:0] b,
    input  wire               sel,
    output wire [w_WIDTH-1:0] o
);

    assign o = sel ? b : a;

endmodule
