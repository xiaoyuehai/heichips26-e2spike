module nbit_adder #(
    parameter integer w_WIDTH = 8
) (
    input  wire [w_WIDTH-1:0] a,
    input  wire [w_WIDTH-1:0] b,
    input  wire               cin,
    output wire [w_WIDTH-1:0] sum,
    output wire               cout
);

    wire [w_WIDTH:0] result;

    assign result = {1'b0, a} +
                    {1'b0, b} +
                    {{w_WIDTH{1'b0}}, cin};

    assign sum  = result[w_WIDTH-1:0];
    assign cout = result[w_WIDTH];

endmodule
