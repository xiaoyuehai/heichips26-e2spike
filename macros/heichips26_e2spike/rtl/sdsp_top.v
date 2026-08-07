module sdsp_top #(
    parameter integer w_WIDTH = 8
) (
    input  wire               up,
    input  wire               down,
    input  wire               spk_pre,
    input  wire               bist,
    input  wire [w_WIDTH-1:0] w,
    output wire [w_WIDTH-1:0] w_next,
    input  wire               clk,
    input  wire               rst
);

    wire               cin;
    wire               cout;
    wire [w_WIDTH-1:0] delta_w;
    wire               sel;
    wire [w_WIDTH-1:0] sum;
    wire [w_WIDTH-1:0] w_new;

    delta_w_generator #(
        .w_WIDTH (w_WIDTH)
    ) u1_delta_w_generator (
        .up      (up),
        .down    (down),
        .spk_pre (spk_pre),
        .bist    (bist),
        .w_msb   (w[w_WIDTH-1]),
        .delta_w (delta_w),
        .cin     (cin)
    );

    overflow_detector u2_overflow_detector (
        .a     (delta_w[0]),
        .cin   (cin),
        .carry (cout),
        .y     (sel)
    );

    nbit_adder #(
        .w_WIDTH (w_WIDTH)
    ) u3_nbit_adder (
        .a    (delta_w),
        .b    (w),
        .cin  (cin),
        .sum  (sum),
        .cout (cout)
    );

    mux #(
        .w_WIDTH (w_WIDTH)
    ) u4_mux (
        .a   (sum),
        .b   (w),
        .sel (sel),
        .o   (w_new)
    );

    d_ff #(
        .w_WIDTH (w_WIDTH)
    ) u5_d_ff (
        .clk (clk),
        .rst (rst),
        .d   (w_new),
        .q   (w_next)
    );

endmodule
