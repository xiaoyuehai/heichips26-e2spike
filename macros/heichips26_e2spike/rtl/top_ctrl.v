module TOP_CTRL (
    input wire  clk,
    input wire  rst_n,
    input wire  ds_block_start,
    output wire  ds_block_end,
    input wire [7:0] max_lenth, //input length

    output wire global_set_enable,
    output wire pixel_start,
    output reg [7:0] fetch_s_addr,
    input wire  pixel_all_t_done//,
    // output wire spike_wb_en,
    // input wire  spike_wb_finish

);
    localparam IDLE = 3'b000;
    localparam ISSUE_GLOBAL = 3'b001;
    localparam ISSUE_PIXEL_START = 3'b010;
    localparam WAIT = 3'b011;
    localparam WB_SPIKE = 3'b100;

    reg [2:0] state, next_state;

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end

    always@(*)begin
        case(state)
            IDLE:begin
                if(ds_block_start == 1'b1)begin
                    next_state = ISSUE_GLOBAL;
                end
                else begin
                    next_state = IDLE;
                end
            end
            ISSUE_GLOBAL:begin // one pooling operation
                next_state = ISSUE_PIXEL_START;
            end
            ISSUE_PIXEL_START:begin
                next_state = WAIT;
            end
            WAIT:begin
                if(pixel_all_t_done == 1'b1)begin
                    if(fetch_s_addr[0] == 1'b1)begin //reason: two->one
                        next_state = WB_SPIKE;
                    end
                    else begin
                        next_state = ISSUE_PIXEL_START;
                    end
                end
                else begin
                    next_state = WAIT;
                end
            end
            WB_SPIKE:begin
                // if(spike_wb_finish == 1'b1)begin
                    if(fetch_s_addr == max_lenth)begin
                        next_state = IDLE;
                    end
                    else begin
                        next_state = ISSUE_GLOBAL;
                    end
                // end
                // else begin
                //     next_state = WB_SPIKE;
                // end
            end
            default:begin
                next_state = IDLE;
            end
        endcase
    end

    always@(posedge clk)begin
        if(ds_block_start)begin
            fetch_s_addr <= 8'h0;
        end
        else if(pixel_all_t_done == 1'b1)begin
            fetch_s_addr <= fetch_s_addr + 1;
        end
    end

    assign global_set_enable = state == ISSUE_GLOBAL;
    assign pixel_start = state == ISSUE_PIXEL_START;
    assign ds_block_end = state == WB_SPIKE && next_state == IDLE;
    // assign spike_wb_en = state == WAIT && next_state == WB_SPIKE;

endmodule