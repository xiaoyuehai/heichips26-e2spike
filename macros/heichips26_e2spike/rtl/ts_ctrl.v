module TS_CTRL(
    input wire  clk,
    input wire  rst_n,
    input wire  pixel_start,
    input wire  pixel_finish,
    output wire fetch_en,
    output reg [1:0] time_step,
    output reg  pixel_all_t_done,

    output wire spike_wb_en,
    input wire  spike_wb_finish
);

    reg [2:0] state,next_state;
    localparam IDLE = 3'b000;
    localparam ISSUE  = 3'b001;
    localparam WAIT = 3'b010;
    localparam TMP = 3'b011;
    localparam WB_SPIKE = 3'b100;

    always@(posedge clk or negedge rst_n) begin
        if(rst_n == 1'b0) begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end

    always@(*) begin
        case(state)
            IDLE:begin
                if(pixel_start)begin
                    next_state = ISSUE;
                end
                else begin
                    next_state = IDLE;
                end
            end
            ISSUE: begin
                next_state = WAIT;
            end
            WAIT: begin
                if(pixel_finish)begin
                    next_state = TMP;
                    // if(time_step == 2'b11)begin
                    //     next_state = IDLE;
                    // end
                    // else begin
                    //     next_state = ISSUE;
                    // end
                end
                else begin
                    next_state = WAIT;
                end
            end
            TMP: begin
                next_state = WB_SPIKE;
            end
            WB_SPIKE: begin
                if(spike_wb_finish)begin
                    if(time_step == 2'b11)begin
                        next_state = IDLE;
                    end
                    else begin
                        next_state = ISSUE;
                    end
                end
                else begin
                    next_state = WB_SPIKE;
                end
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    always@(posedge clk)begin
        if(state == IDLE)begin
            time_step <= 2'b00;
        end
        else if(state == WB_SPIKE && spike_wb_finish)begin
            time_step <= time_step + 1'b1;
        end
    end

    assign fetch_en = state == ISSUE;

    always@(posedge clk or negedge rst_n) begin
        if(rst_n == 1'b0)begin
            pixel_all_t_done <= 1'b0;
        end
        else if(state == WB_SPIKE && next_state == IDLE)begin
            pixel_all_t_done <= 1'b1;
        end
        else begin
            pixel_all_t_done <= 1'b0;
        end
    end

    assign spike_wb_en = state == TMP && next_state == WB_SPIKE;

endmodule