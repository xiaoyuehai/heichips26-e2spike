module learning_top #(
    parameter integer w_WIDTH = 4
) (
    input  wire               clk,
    input  wire               rst,
    input  wire               sample_start,
    input  wire               learn_en,
    input  wire [15:0]        Vmem,
    input  wire               spk_post,
    input  wire               spk_pre,
    input  wire [w_WIDTH-1:0] w,
    output reg  [w_WIDTH-1:0] w_next
);

    wire [2:0]         ca;
    wire               up;
    wire               down;
    wire [w_WIDTH-1:0] w_new;

    ca_counter inst_ca_counter (
        .clk          (clk),
        .rst          (rst),
        .sample_start (sample_start),
        .spk_post     (spk_post),
        .leak_event   (1'b0),
        .ca           (ca)
    );

    comparator inst_comparator (
        .ca   (ca),
        .Vmem (Vmem),
        .up   (up),
        .down (down)
    );

    sdsp_top #(
        .w_WIDTH (w_WIDTH)
    ) inst_sdsp_top (
        .up      (up),
        .down    (down),
        .spk_pre (spk_pre),
        .bist    (1'b0),
        .w       (w),
        .w_next  (w_new),
        .clk     (clk),
        .rst     (rst)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            w_next <= w;
        end else if (spk_pre) begin
            if (learn_en)
                w_next <= w_new;
            else
                w_next <= w;
        end
    end

endmodule
