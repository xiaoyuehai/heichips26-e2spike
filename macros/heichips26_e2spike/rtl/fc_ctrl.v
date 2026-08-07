module FC_CTRL#(
    parameter RW_GAP_CYCLE = 2
)(
    input wire                  clk,
    input wire                  rst_n,

    input wire                  fc_start,
    output wire                 fc_finish,
    input wire                  pixel_finish,
    input wire                  final_cls_layer,
    input wire [3:0]            lenth_for_after_avg_pooling,//10
    input wire [7:0]            mem_len_per_t,

    output wire                 fc_spike_vld,
    // output wire [1:0]           fc_spike_data,
    // input wire                  shift_spike_from_sparse,

    // SRAM read port
    output wire [8:0]            sram_r_addr,
    output wire                 sram_ren,
    // input  wire [63:0]          sram_r_data,

    //fc special output
    output wire                 fc_in_computing,
    output wire                 acc_only_enable,
    output wire                 fc_first_pixel_one_t,
    output reg [1:0]            fc_time_step,
    output wire                 fc_wb_spike_en,
    input wire                  fc_wb_spike_finish,
    input wire [RW_GAP_CYCLE-1:0]   shift_for_mem_bit_trans
);

    reg [8:0] fetch_fc_spike_addr;
    
    reg [3:0] state,next_state;
    reg [3:0] did_pixel_cnt;
    wire final_pixel;
    wire fc_spike_rd_en;

    localparam IDLE = 4'd0;
    localparam FETCH_FC_SPIKE = 4'd1;
    localparam FETCH_FC_SPIKE_OK = 4'd2;
    localparam TRIGER_CMP = 4'd3;
    localparam WAIT = 4'd4;
    localparam TS = 4'd5;
    localparam WB_SPIKE = 4'd6;
    localparam TMP = 4'd7;

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
                if(fc_start == 1'b1)begin
                    next_state = FETCH_FC_SPIKE;
                end
                else begin
                    next_state = IDLE;
                end
            end
            FETCH_FC_SPIKE:begin
                next_state = FETCH_FC_SPIKE_OK;
            end
            FETCH_FC_SPIKE_OK:begin
                if(shift_for_mem_bit_trans[RW_GAP_CYCLE-1] == 1'b1)begin
                    next_state = TRIGER_CMP;
                end
                else begin
                    next_state = FETCH_FC_SPIKE_OK;
                end
            end
            TRIGER_CMP:begin
                next_state = WAIT;
            end
            WAIT:begin
                if(pixel_finish == 1'b1)begin
                    if(final_pixel)begin
                        next_state = final_cls_layer ? TS : TMP;
                    end
                    else begin
                        next_state = FETCH_FC_SPIKE;
                    end
                end
                else begin
                    next_state = WAIT;
                end
            end
            TMP: begin
                next_state = WB_SPIKE;
            end
            WB_SPIKE:begin
                next_state = fc_wb_spike_finish ? TS : WB_SPIKE;
            end
            TS: begin
                if(fc_time_step == 2'b11)begin
                    next_state = IDLE;
                end
                else begin
                    next_state = FETCH_FC_SPIKE;
                end
            end
            // WB_SPIKE:begin
            //     if(fc_wb_spike_finish == 1'b1)begin
            //         next_state = IDLE;
            //     end
            //     else begin
            //         next_state = WB_SPIKE;
            //     end
            // end
            default:begin
                next_state = IDLE;
            end
        endcase
    end

    assign fc_finish = state == TS && next_state == IDLE;
    assign fc_spike_rd_en = state == FETCH_FC_SPIKE;
    // assign fc_wb_spike_en = state == TS && next_state == WB_SPIKE;
    assign fc_wb_spike_en = state == TMP;

    always@(posedge clk)begin
        if(fc_start == 1'b1)begin
            fetch_fc_spike_addr <= 9'd0;
        end
        else if(next_state == FETCH_FC_SPIKE && state == TS)begin
            case(fc_time_step)
                2'b00: fetch_fc_spike_addr <= 40;
                2'b01: fetch_fc_spike_addr <= 80;
                2'b10: fetch_fc_spike_addr <= 120;
                2'b11: fetch_fc_spike_addr <= 0;
                default: fetch_fc_spike_addr <= 9'd0;
            endcase
        end
        else if(state == FETCH_FC_SPIKE)begin
            fetch_fc_spike_addr <= fetch_fc_spike_addr + 1'b1;
        end
    end

    assign fc_spike_vld = state == TRIGER_CMP;
    
    // reg [31:0] fc_spike_data_low;
    // reg [31:0] fc_spike_data_high;

    // always@(posedge clk)begin
    //     if(fc_spike_vld)begin
    //         if(~final_cls_layer)begin
    //             fc_spike_data_low <= sram_r_data[31:0];
    //             fc_spike_data_high <= sram_r_data[63:32];
    //         end
    //         else begin
    //             fc_spike_data_low <= {24'b0, sram_r_data[31:24]};
    //             fc_spike_data_high <= {24'b0, sram_r_data[63:56]};
    //         end
    //     end
    //     else if(shift_spike_from_sparse)begin
    //         fc_spike_data_low <= {1'b0, fc_spike_data_low[31:1]};
    //         fc_spike_data_high <= {1'b0, fc_spike_data_high[31:1]};
    //     end
    // end

    always@(posedge clk)begin
        if(fc_start)begin
            fc_time_step <= 2'b00;
        end
        else if(state == TS)begin
            if(fc_time_step == 2'b11)begin
                fc_time_step <= 2'b00;
            end
            else begin
                fc_time_step <= fc_time_step + 1'b1;
            end
        end
    end

    assign sram_ren = fc_spike_rd_en;
    assign sram_r_addr = fetch_fc_spike_addr;
    // assign fc_spike_data = {fc_spike_data_high[0], fc_spike_data_low[0]};

    always@(posedge clk)begin
        if(fc_start || state == TS || state == IDLE)begin
            did_pixel_cnt <= 4'd0;
        end
        else if(pixel_finish)begin
            did_pixel_cnt <= did_pixel_cnt + 1'b1;
        end
    end

    assign final_pixel = did_pixel_cnt == lenth_for_after_avg_pooling - 1;
    assign fc_in_computing = state != IDLE && state != WB_SPIKE;
    assign acc_only_enable = (~final_pixel) && fc_in_computing;
    assign fc_first_pixel_one_t = did_pixel_cnt == 4'd0;

    
endmodule