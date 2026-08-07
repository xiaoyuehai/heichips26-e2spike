module FETCH_SPIKE #(
    parameter RW_GAP_CYCLE = 2
)(
    input wire                              clk                     ,
    input wire                              rst_n                   ,
    input wire  [1:0]                       time_step               ,
    input wire  [7:0]                       mem_len_per_t           ,
    input wire                              row_has_two             ,
    input wire  [7:0]                       max_lenth               ,
    input wire                              fetch_en                ,
    input wire  [7:0]                       fetch_s_addr            , 

    output wire  [8:0]                      sram_r_addr             , 
    output wire                             sram_wen                ,
    output wire                             sram_ren                ,
    input  wire  [63:0]                     sram_r_data             ,
    output wire  [63:0]                     sram_w_data             ,
    output wire                             fetch_done              ,

    // shift for compute
    input wire                              shift_en                ,
    output wire [31:0]                      pixel_out               ,
    input wire [RW_GAP_CYCLE-1:0]           shift_for_mem_bit_trans ,
    input wire [3:0]                        input_channels_52       ,
    input wire [3:0]                        read_times              ,
    input wire                              dense_cal_done
);
    ////////////////////////////////// reg ////////////////////
    reg [2:0]                               cnt                     ;
    // reg                                     fetch_in_progress       ;
    reg [7:0]                               r_addr                  ;
    reg [15:0]                              dw_src_data_0           ;// HIGH Priority for PPA
    reg [15:0]                              dw_src_data_1           ;
    reg [7:0]                               a                       ;
    reg                                     r_data_vld              ;
    reg                                     r_data_vld_ff1          ;
    reg                                     r_data_vld_ff2          ;
    reg                                     r_idx                   ;
    reg [31:0]                              save_data_0             ;
    reg [31:0]                              save_data_1             ;
    reg [3:0]                               pixel_0_low             ;
    reg [3:0]                               pixel_0_high            ;
    reg [3:0]                               pixel_1_low             ;
    reg [3:0]                               pixel_1_high            ;
    reg [3:0]                               pixel_2_low             ;
    reg [3:0]                               pixel_2_high            ;
    reg [3:0]                               pixel_3_low             ;
    reg [3:0]                               pixel_3_high            ;
    reg [1:0]                               mem_op_seq              ;
    reg [2:0]                               state,next_state        ;
    wire                                    rw_one_ok               ;
        
    always@(*)begin
        case(time_step)
            2'b00: a = 0;
            2'b01: a = 40;
            2'b10: a = 80;
            2'b11: a = 120;
            default: a = 8'h0;
        endcase
    end

    localparam IDLE = 3'b000;
    localparam CHECK_READ_TIMES = 3'b001;
    localparam CHECK_ONE_TIME = 3'b010;
    localparam READ_WRITE           = 3'b011;
    localparam WAIT_DENSE_CAL          = 3'b100;

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
            IDLE: begin
                if(fetch_en == 1'b1) begin
                    next_state = CHECK_READ_TIMES;
                end
                else begin
                    next_state = IDLE;
                end
            end
            CHECK_READ_TIMES: begin
                if(read_times == input_channels_52) begin
                    next_state = IDLE;
                end
                else begin
                    next_state = CHECK_ONE_TIME;
                end
            end
            CHECK_ONE_TIME: begin
                if(cnt == 3'd4) begin
                    next_state = WAIT_DENSE_CAL;//CHECK_READ_TIMES;
                end
                else begin
                    next_state = READ_WRITE;
                end
            end
            READ_WRITE: begin
                if(rw_one_ok == 1'b1) begin
                    next_state = CHECK_ONE_TIME;
                end
                else begin
                    next_state = READ_WRITE;
                end
            end
            WAIT_DENSE_CAL: begin
                if(dense_cal_done == 1'b1) begin
                    next_state = CHECK_READ_TIMES;
                end
                else begin
                    next_state = WAIT_DENSE_CAL;
                end
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    wire fetch_trigger = state == CHECK_READ_TIMES && next_state == CHECK_ONE_TIME;
    assign fetch_done = state == CHECK_ONE_TIME && next_state == WAIT_DENSE_CAL;

    always@(posedge clk) begin
        if(fetch_trigger == 1'b1) begin
            cnt <= 3'd0;
        end
        else if(sram_ren == 1'b1) begin
            cnt <= cnt + 1'b1;
        end
    end

    always@(posedge clk) begin // todo: PPA optimize
        if(fetch_trigger == 1'b1) begin
            r_addr <= fetch_s_addr;// + a;
        end
        else if(sram_wen == 1'b1) begin
            r_addr <= r_addr + 1'b1;
        end
    end

    assign sram_ren     = state == CHECK_ONE_TIME && next_state == READ_WRITE;

    reg [8:0] sram_r_addr_tmp;

    always@(*) begin
        // if(r_addr >= max_lenth) begin
        //     sram_r_addr_tmp = 9'h1FF;
        // end
        // else begin
            sram_r_addr_tmp = row_has_two == 1'b0 ? {1'b0, r_addr} : {2'b0, r_addr[7:1]};
        // end
    end

    assign sram_r_addr = sram_r_addr_tmp + a;// + rd_spike_base_addr;

    reg rd_data_is_zeros;
    always@(posedge clk or negedge rst_n) begin
        if(rst_n == 1'b0) begin
            rd_data_is_zeros <= 1'b0;
        end
        else if(sram_ren)begin //&r_addr
            rd_data_is_zeros <= r_addr >= max_lenth;//1'b1;
        end
    end

    always@(posedge clk) begin
        // r_data_vld <= sram_ren;
        // r_data_vld_ff1 <= r_data_vld;
        r_data_vld_ff2 <= shift_for_mem_bit_trans[RW_GAP_CYCLE-1] & mem_op_seq[0];//r_data_vld_ff1;
        if(sram_ren == 1'b1) begin
            r_idx <= r_addr[0];
        end
    end

    always@(*)begin
        if(rd_data_is_zeros == 1'b1) begin
            save_data_0 = 32'd0;
            save_data_1 = 32'd0;
        end
        else if(row_has_two == 1'b1) begin
            case(r_idx)
                1'b0: begin save_data_0 = {16'b0, sram_r_data[15:0]}; save_data_1 <= {16'b0, sram_r_data[47:32]}; end                                        
                1'b1: begin save_data_0 = {16'b0, sram_r_data[31:16]}; save_data_1 <= {16'b0, sram_r_data[63:48]}; end
                default: begin save_data_0 = 32'd0; save_data_1 = 32'd0; end
            endcase
        end
        else begin
            save_data_0 = sram_r_data[31:0];
            save_data_1 = sram_r_data[63:32];
        end
    end

    always@(posedge clk) begin
        if(r_data_vld_ff2 == 1'b1) begin
            dw_src_data_0 <= {save_data_0[3:0], dw_src_data_0[15:4]};//low
            dw_src_data_1 <= {save_data_1[3:0], dw_src_data_1[15:4]};//high
        end
        // else if(shift_en == 1'b1) begin
        //     dw_src_data_0 <= {4'b0, dw_src_data_0[127:4]};
        //     dw_src_data_1 <= {4'b0, dw_src_data_1[127:4]};
        // end
    end

    assign sram_wen = r_data_vld_ff2 & ~rd_data_is_zeros; //r_data_vld_ff1 == 1'b0 && r_data_vld_ff2 == 1'b1 && fetch_in_progress == 0;
    wire [31:0] lo = sram_r_data[31:0], hi = sram_r_data[63:32];
    wire [31:0] lo_rot = ~row_has_two ? {lo[3:0], lo[31:4]} :
                     r_idx ? {lo[19:16], lo[31:20], lo[15:0]}
                           : {lo[31:16], lo[3:0],  lo[15:4]};
    wire [31:0] hi_rot = ~row_has_two ? {hi[3:0], hi[31:4]} :
                     r_idx ? {hi[19:16], hi[31:20], hi[15:0]}
                           : {hi[31:16], hi[3:0],  hi[15:4]};
    
    assign sram_w_data = {hi_rot, lo_rot};

    // output shift for compute
    always@(posedge clk) begin
        // if(shift_en == 1'b1) begin
            pixel_0_low <= dw_src_data_0[3:0];
            pixel_0_high <= dw_src_data_1[3:0];

            pixel_1_low <= dw_src_data_0[7:4];
            pixel_1_high <= dw_src_data_1[7:4];

            pixel_2_low <= dw_src_data_0[11:8];
            pixel_2_high <= dw_src_data_1[11:8];

            pixel_3_low <= dw_src_data_0[15:12];
            pixel_3_high <= dw_src_data_1[15:12];
        // end
    end
    wire [7:0] c0 = {pixel_3_high[0],pixel_3_low[0],pixel_2_high[0],pixel_2_low[0], pixel_1_high[0],pixel_1_low[0],pixel_0_high[0],pixel_0_low[0]};
    wire [7:0] c1 = {pixel_3_high[1],pixel_3_low[1],pixel_2_high[1],pixel_2_low[1], pixel_1_high[1],pixel_1_low[1],pixel_0_high[1],pixel_0_low[1]};
    wire [7:0] c2 = {pixel_3_high[2],pixel_3_low[2],pixel_2_high[2],pixel_2_low[2], pixel_1_high[2],pixel_1_low[2],pixel_0_high[2],pixel_0_low[2]};
    wire [7:0] c3 = {pixel_3_high[3],pixel_3_low[3],pixel_2_high[3],pixel_2_low[3], pixel_1_high[3],pixel_1_low[3],pixel_0_high[3],pixel_0_low[3]};

    assign pixel_out = {c3, c2, c1, c0};

    always@(posedge clk or negedge rst_n) begin
        if(rst_n == 1'b0) begin
            mem_op_seq <= 2'b0;
        end
        else if(sram_wen == 1'b1 || sram_ren == 1'b1) begin
            mem_op_seq <= {sram_wen, sram_ren};
        end
    end

    // assign rw_one_ok = shift_for_mem_bit_trans[RW_GAP_CYCLE-1] && mem_op_seq[1];
    assign rw_one_ok = shift_for_mem_bit_trans[RW_GAP_CYCLE-1] &&
                   (mem_op_seq[1] || (mem_op_seq[0] && rd_data_is_zeros));
endmodule