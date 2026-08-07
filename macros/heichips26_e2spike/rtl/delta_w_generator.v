module delta_w_generator #(
    parameter integer w_WIDTH = 8
) (
    input  wire               up,
    input  wire               down,
    input  wire               spk_pre,
    input  wire               bist,
    input  wire               w_msb,
    output reg  [w_WIDTH-1:0] delta_w,
    output reg                cin
);

    always @* begin
        delta_w = {w_WIDTH{1'b0}};
        cin     = 1'b0;

        if (spk_pre) begin
            if (up) begin
                cin = 1'b1;
            end else if (down) begin
                delta_w = {w_WIDTH{1'b1}};
            end
        end else if (bist) begin
            if (w_msb == 1'b1) begin
                cin = 1'b1;
            end else if (w_msb == 1'b0) begin
                delta_w = {w_WIDTH{1'b1}};
            end
        end
    end

endmodule
