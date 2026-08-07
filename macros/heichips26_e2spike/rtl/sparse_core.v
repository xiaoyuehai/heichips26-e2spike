`timescale 1ns / 1ps
module SPARSE_CORE #(
    parameter RW_GAP_CYCLE = 2
)(
    input wire                      clk                     ,
    input wire                      rst_n                   ,
    input wire                      final_cls_layer         ,
    input wire                      pixel_start             ,
    input wire                      global_set_enable       ,
    input wire                      spike_wb_en             ,
    output reg                      spike_wb_finish         ,
    input wire                      ds_block_start          ,
    input wire  [7:0]               mem_len_per_t           ,
    // data from dense core
    input wire  [1:0]               spike_one_pixel         ,
    input wire                      spike_one_pixel_valid   ,
    output wire                     shift_spike_from_sparse ,

    // config
    input wire  [5:0]               input_channels          ,
    input wire  [5:0]               pw_output_channels      ,
    output wire                     pixel_finish            ,
    input wire  [1:0]               time_step               ,

    // SRAM read port
    input wire                      sram_ren                ,
    input  wire [63:0]              sram_r_data             ,
    input wire                      sram_wen                ,
    output wire  [63:0]             sram_w_data             ,
    output wire  [8:0]              sparse_spike_waddr      ,
    output wire                     sparse_spike_wen        ,
    output wire                     sparse_spike_ren        ,
    input wire   [7:0]              fetch_s_addr            ,
    // fc special input
    input wire                      fc_start                ,
    input wire                      fc_in_computing         ,
    input wire                      acc_only_enable         ,
    input wire                      fc_first_pixel_one_t    ,

    output wire                     class_label             ,

    // interaction between dual-mode PE
    output wire                     sparse_mp_clr           ,
    output wire [1:0]               sparse_act              ,
    output wire                     sparse_acc_en           ,
    output wire                     sparse_scale_en         ,
    output wire [1:0]               sparse_bias_en          ,
    output wire [1:0]               sparse_mp_en            ,
    output wire                     sparse_spike_en         ,
    output reg [15:0]               pooling_input           ,
    input wire [15:0]               pooling_output          ,
    input wire [127:0]              wb_mp_data              ,

    // connect to addr generator
    output wire                     pw_weight_en            ,
    output reg                      pw_scale_en             ,
    output wire [1:0]               combined_bias_rd_en     ,
    output wire [1:0]               combined_pw_mp_en       ,
    output wire                     pw_wb_mp_en             ,
    input wire                      fc_spike_vld            ,
    output wire [1:0]               fc_spike_data           ,
    input wire [RW_GAP_CYCLE-1:0]   shift_for_mem_bit_trans ,
    input wire                      online_training_disable ,
    output reg                      pw_weight_wr_en         ,
    input wire [7:0]                updated_weight          

    );

    ////////////////////////////////// reg ////////////////////
    reg [4:0]                       shift_cnt               ;
    reg [1:0]                       act                     ;
    reg                             fc_flag                 ;
    reg                             wb_mp_0, wb_mp_1, wb_mp_finish        ;
    reg [1:0]                       did_multi_times         ;
    reg                             cal_in_progress         ;
    reg                             cal_in_progress_ff1     ;
    reg                             cal_busy                ;
    reg                             wb_spike_en             ;
    reg                             spike_rd_en             ;
    reg [10:0]                       read_en_seq             ;
    reg                             pw_weight_en_flag       ;
    reg                             pw_weight_en_ff1        ;
    reg                             bias_rd_en              ;
    reg                             bias_rd_en_ff1          ;
    reg                             mp_rd_en                ;
    reg                             mp_rd_en_ff1            ;
    reg                             acc_en                  ;
    reg                             scale_en                ;
    reg [1:0]                       bias_en                 ;
    reg [1:0]                       mp_en                   ;
    reg                             spike_en                ;
    reg [8:0]                       wb_spike_addr           ;
    reg [8:0]                       wb_spike_internal_addr  ;
    reg [63:0]                      sel_wb_spike_data       ;
    reg                             rd_pw_weight_flag       ;
    
    ////////////////////////////////// wire ///////////////////
    wire                            wb_mp_en                ;
    wire [2:0]                      multi_times             ;
    wire                            cal_enable              ;
    wire [3:0]                      combined_wb_spike_en    ;
    wire [1:0]                      combined_wb_mp_en       ;
    wire [1:0]                      combined_mp_rd_en       ;
    wire                            pw_bias_en              ;
    wire                            pw_mp_en                ;
    wire [8:0]                      wb_spike_addr_base      ;
    wire [63:0]                     real_wb_spike_data      ;
    wire [1:0]                      multi_times_sub_1       ;
    wire                            did_equal_multi_times   ;
    wire [5:0]                      input_channels_sub_1    ;
    // wire [1:0] combined_bias_rd_en;
    

    assign pw_wb_mp_en = wb_mp_en & ~acc_only_enable;
    
    assign multi_times = pw_output_channels[5:3];
    
    // match memory
    always@(posedge clk or negedge rst_n) begin
        if(rst_n == 1'b0) begin
            read_en_seq <= 12'h0;
        end
        else if(sram_ren == 1'b1 || sram_wen == 1'b1) begin
            read_en_seq <= {pw_weight_wr_en, spike_rd_en, wb_spike_en, combined_wb_mp_en[1:0], pw_weight_en, pw_scale_en, combined_bias_rd_en[1:0], combined_mp_rd_en[1:0]};
        end
    end
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////
    assign multi_times_sub_1 = multi_times - 1;
    assign did_equal_multi_times = did_multi_times == multi_times_sub_1;
    assign input_channels_sub_1 = input_channels - 1;
    always@(posedge clk or negedge rst_n) begin
        if(rst_n == 1'b0)begin
            cal_in_progress <= 1'b0;
        end
        else if(spike_one_pixel_valid)begin
            cal_in_progress <= 1'b1;
        end
        else if(did_equal_multi_times && cal_in_progress) begin //& wb_mp_1
            cal_in_progress <= 1'b0;
        end
    end

    assign pixel_finish = wb_mp_finish && did_equal_multi_times;
    always@(posedge clk or negedge rst_n) begin
        if(rst_n == 1'b0) begin
            did_multi_times <= 'd0;
        end
        else if(wb_mp_finish == 1'b1) begin
            if(did_equal_multi_times) begin
                did_multi_times <= 'd0;
            end
            else begin
                did_multi_times <= did_multi_times + 1'b1;
            end
        end
    end

    assign cal_enable = cal_in_progress & ~cal_busy;

    always@(posedge clk or negedge rst_n) begin
        if(rst_n == 1'b0) begin
            cal_busy <= 1'b0;
        end
        else if(cal_enable)begin
            cal_busy <= 1'b1;
        end
        else if(wb_mp_finish == 1'b1)begin
            cal_busy <= 1'b0;
        end
    end

    

    //////////////////////////////////////////////////////////////////////////////

    always@(posedge clk) begin
        if(shift_spike_from_sparse)begin
            act <= spike_one_pixel;
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            shift_cnt <= 6'd0;
        end
        else if(shift_spike_from_sparse)begin
            if(shift_cnt == input_channels_sub_1)begin
                shift_cnt <= 6'd0;
            end
            else begin
                shift_cnt <= shift_cnt + 1'b1;
            end
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            pw_weight_en_flag <= 1'b0;
        end
        else if(cal_enable)begin
            pw_weight_en_flag <= 1'b1;
        end
        else if(shift_cnt == input_channels_sub_1 && pw_weight_en)begin
            pw_weight_en_flag <= 1'b0;
        end
    end

    assign pw_weight_en = pw_weight_en_flag & ~|shift_for_mem_bit_trans & ~rd_pw_weight_flag;
    
    /// on-chip learning control --- yuehai
    // reg rd_pw_weight_flag;
    reg pw_weight_wr_en_internal;
    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            rd_pw_weight_flag <= 1'b0;
        end
        else if(online_training_disable || ~final_cls_layer)begin
            rd_pw_weight_flag <= 1'b0;
        end
        else if(pw_weight_en) begin
            rd_pw_weight_flag <= 1'b1;
        end
        else if(shift_for_mem_bit_trans[RW_GAP_CYCLE-1] && read_en_seq[10])begin
            rd_pw_weight_flag <= 1'b0;
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            pw_weight_wr_en_internal <= 1'b0;
        end
        else if(online_training_disable || ~final_cls_layer)begin
            pw_weight_wr_en_internal <= 1'b0;
        end
        else if(shift_for_mem_bit_trans[RW_GAP_CYCLE-1] && read_en_seq[5])begin
            pw_weight_wr_en_internal <= 1'b1;
        end
        else begin
            pw_weight_wr_en_internal <= 1'b0;
        end
    end

    always@(posedge clk)begin
        pw_weight_wr_en <= pw_weight_wr_en_internal;
    end

    // assign updated_weight = {sram_r_data[63:8], updated_weight[7:0]};

    //////////////////////////////////////////////////////////////

    assign shift_spike_from_sparse = pw_weight_en;

    // read_scale
    always@(posedge clk)begin
        pw_weight_en_ff1 <= pw_weight_en;
    end

    always@(posedge clk)begin
        if(shift_for_mem_bit_trans[RW_GAP_CYCLE-1] == 1'b1 && (~final_cls_layer || online_training_disable)) begin
            pw_scale_en <= read_en_seq[5] & ~pw_weight_en_flag;
        end
        else if(shift_for_mem_bit_trans[RW_GAP_CYCLE-1] && (final_cls_layer && ~online_training_disable))begin
            pw_scale_en <= read_en_seq[10] & ~pw_weight_en_flag;
        end
        else begin
            pw_scale_en <= 0;
        end
    end

    // read_bias
    assign    pw_bias_en = bias_rd_en | bias_rd_en_ff1;
    assign    combined_bias_rd_en = {bias_rd_en, bias_rd_en_ff1};

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            bias_rd_en <= 1'b0;
        end
        else if(shift_for_mem_bit_trans[RW_GAP_CYCLE-1] == 1'b1)begin
            bias_rd_en <= read_en_seq[4];//pw_scale_en;
        end
        else begin
            bias_rd_en <= 0;
        end
    end

    always@(posedge clk)begin
        if(shift_for_mem_bit_trans[RW_GAP_CYCLE-1] == 1'b1) begin
            bias_rd_en_ff1 <= read_en_seq[3];//pw_scale_en;
        end
        else begin
            bias_rd_en_ff1 <= 0;
        end
    end

    // add one stage for read_spike, when T != 0;
    always@(posedge clk)begin
        if(shift_for_mem_bit_trans[RW_GAP_CYCLE-1] == 1'b1) begin
            if(read_en_seq[2] && did_multi_times == 0 && fetch_s_addr[0])begin
                spike_rd_en <= 1'b1;
            end
            else begin
                spike_rd_en <= 0;
            end
        end
        else begin
            spike_rd_en <= 0;
        end
    end

    // mp
    assign    pw_mp_en = mp_rd_en | mp_rd_en_ff1;
    assign    combined_mp_rd_en = {mp_rd_en, mp_rd_en_ff1};
    assign    combined_pw_mp_en = combined_mp_rd_en;

    always@(posedge clk)begin
        if(shift_for_mem_bit_trans[RW_GAP_CYCLE-1] == 1'b1)begin
            if(did_multi_times == 0 && fetch_s_addr[0])begin
                mp_rd_en <= read_en_seq[9];
            end
            else begin
                mp_rd_en <= read_en_seq[2];
            end
        end
        else begin
            mp_rd_en <= 0;
        end
    end

    always@(posedge clk)begin
        if(shift_for_mem_bit_trans[RW_GAP_CYCLE-1] == 1'b1) begin
            mp_rd_en_ff1 <= read_en_seq[1];
        end
        else begin
            mp_rd_en_ff1 <= 0;
        end
    end

    // compute signal
    assign combined_wb_mp_en = {wb_mp_0, wb_mp_1};
    
    always@(posedge clk)begin
        acc_en <= shift_for_mem_bit_trans[RW_GAP_CYCLE-1] & read_en_seq[5];//pw_weight_en;
        scale_en <= shift_for_mem_bit_trans[RW_GAP_CYCLE-1] & read_en_seq[4];//pw_scale_en;
        bias_en[0] <= shift_for_mem_bit_trans[RW_GAP_CYCLE-1] & read_en_seq[3];//bias_rd_en_ff1;
        bias_en[1] <= shift_for_mem_bit_trans[RW_GAP_CYCLE-1] & read_en_seq[2];//bias_rd_en;
        // bias_en[1:0] <= {bias_en[0], bias_rd_en};
        // mp_en[1:0] <= {mp_en[0], mp_rd_en};
        mp_en[0] <= shift_for_mem_bit_trans[RW_GAP_CYCLE-1] & read_en_seq[1];//mp_rd_en_ff1;
        mp_en[1] <= shift_for_mem_bit_trans[RW_GAP_CYCLE-1] & read_en_seq[0];//mp_rd_en;
        spike_en <= mp_en[1];//mp_rd_en_ff1;

        wb_mp_0 <= spike_en;
        wb_mp_1 <= acc_only_enable ? wb_mp_0 : shift_for_mem_bit_trans[RW_GAP_CYCLE-1] & read_en_seq[7];//wb_mp_0;
        wb_mp_finish <= acc_only_enable ? wb_mp_1 : shift_for_mem_bit_trans[RW_GAP_CYCLE-1] & read_en_seq[6];

    end

    assign wb_mp_en = wb_mp_0 | wb_mp_1;

    
     genvar i;
    // wire [15:0] spike_out;
    // reg [15:0] pooling_input;
    // wire [15:0] pooling_output;
    // wire [127:0] wb_mp_data;
    // generate
    //     for(i=0;i<8;i=i+1)begin : spe_gen
    //         SPE U_SPE (
    //             .clk         (clk),
    //             .rst_n       (rst_n),
    //             .final_cls_layer (final_cls_layer),

    //             .time_step   (time_step),
    //             .act         (act),
    //             .in_w        (fc_in_computing ? sram_r_data[32+i*4 +: 4] : sram_r_data[i*4 +: 4]),
    //             .mp_clr      (cal_enable & fc_first_pixel_one_t),
    //             .acc_en      (acc_en ),
    //             .scale_en    (scale_en & ~acc_only_enable),
    //             .scale_value (sram_r_data[i*8 +: 8]),
    //             // word 0 -> SPE0-3, word 1 -> SPE4-7, same lane position in each word
    //             .bias_en     (i >= 4 ? bias_en[1] & ~acc_only_enable : bias_en[0] & ~acc_only_enable),
    //             .bias_value  (sram_r_data[(i%4)*16 +: 16]),
    //             .mp_en       (i >= 4 ? mp_en[1] & ~acc_only_enable : mp_en[0] & ~acc_only_enable),
    //             .mp_value    (sram_r_data[(i%4)*16 +: 16]),
    //             .spike_en    (spike_en & ~acc_only_enable),
    //             .spike_out   (spike_out[i*2 +: 2]), //open
    //             .wb_mp       (wb_mp_data[i*16 +: 16]),

    //             .pooling_input (fc_in_computing ? 0 : pooling_input[i*2 +: 2]),
    //             .pooling_output (pooling_output[i*2 +: 2])
    //         );
    //     end
    // endgenerate

    wire signed [15:0] wb_mp_data_0 = wb_mp_data[15:0];
    wire signed[15:0] wb_mp_data_1 = wb_mp_data[31:16];
    assign class_label = wb_mp_data_0 > wb_mp_data_1 ? 1'b0 : 1'b1;

    assign sparse_mp_clr = cal_enable & fc_first_pixel_one_t;
    assign sparse_act = act;
    assign sparse_acc_en = acc_en;
    assign sparse_scale_en = scale_en & ~acc_only_enable;
    assign sparse_bias_en = ~acc_only_enable ? {bias_en[1], bias_en[0]} : 2'b00;
    assign sparse_mp_en = ~acc_only_enable ? {mp_en[1], mp_en[0]} : 2'b00;

    assign sparse_spike_en = spike_en & ~acc_only_enable;

    reg [63:0] pw_spike_data_t0;

    always@(posedge clk)begin
        if(cal_enable && did_multi_times == 0 && ~acc_only_enable)begin
            pw_spike_data_t0 <= ~fc_flag ? 64'd0 : pw_spike_data_t0;
        end
        else if(mp_rd_en && did_multi_times == 0 && fetch_s_addr[0])begin//shift_for_mem_bit_trans[RW_GAP_CYCLE-1] && read_en_seq[9]
            pw_spike_data_t0 <= sram_r_data;
        end
        //TRY merge reg in fc_ctrl
        else if(fc_flag && fc_spike_vld)begin
            if(~final_cls_layer)begin
                pw_spike_data_t0 <= {sram_r_data[63:32],sram_r_data[31:0]};
                // pw_spike_data_t0 <= {16'b0, sram_r_data[63:48], 16'b0, sram_r_data[31:16]};
            end
            else begin
                pw_spike_data_t0 <= {24'b0, sram_r_data[63:56], 24'b0, sram_r_data[31:24]};
            end
        end
        else if(fc_flag && shift_spike_from_sparse)begin
            pw_spike_data_t0 <= {1'b0, pw_spike_data_t0[63:1]};
        end
        else if(wb_mp_0 & ~acc_only_enable)begin
            pw_spike_data_t0 <= {pooling_output, pw_spike_data_t0[63:16]};
        end
    end
    assign fc_spike_data = {pw_spike_data_t0[32],pw_spike_data_t0[0]};


    always@(*)begin
        pooling_input = pw_spike_data_t0[15:0];
    end

    // spike write back logic
    always@(*)begin
        case(time_step)
            2'b00: wb_spike_internal_addr = 490;
            2'b01: wb_spike_internal_addr = 491;
            2'b10: wb_spike_internal_addr = 492;
            2'b11: wb_spike_internal_addr = 493;
            default: wb_spike_internal_addr = 9'd0;
        endcase
    end

    always@(posedge clk)begin
        wb_spike_en <= spike_wb_en;
    end

    assign wb_spike_addr_base = fc_flag ? 9'd0 : {1'b0, fetch_s_addr[7:1]};

    always@(posedge clk)begin
        if(cal_enable && time_step == 2'b00 && did_multi_times == 0)begin
            wb_spike_addr <= wb_spike_addr_base;
        end
        else if(wb_spike_en)begin
            wb_spike_addr <= wb_spike_addr + mem_len_per_t;
        end
    end

    always@(posedge clk) begin
        if(shift_for_mem_bit_trans[RW_GAP_CYCLE-1])begin
            spike_wb_finish <= read_en_seq[8];
        end
        else begin
            spike_wb_finish <= 0;
        end
    end

    always@(*)begin
        // sel_wb_spike_data = fc_flag ? {pw_spike_data_t0[63:32],32'b0} : pw_output_channels == 16 ? {32'b0,pw_spike_data_t0[63:32]} : pw_spike_data_t0;
        sel_wb_spike_data = pw_output_channels == 16 ? {32'b0,pw_spike_data_t0[63:32]} : pw_spike_data_t0;
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            fc_flag <= 1'b0;
        end
        else if(fc_start)begin
            fc_flag <= 1'b1;
        end
        else if(ds_block_start)begin
            fc_flag <= 1'b0;
        end
    end

    generate
        for(i=0;i<32;i=i+1)begin: spike_gen
            assign real_wb_spike_data[i] = fc_flag || fetch_s_addr[0] ? sel_wb_spike_data[i*2] : sel_wb_spike_data[i];
            assign real_wb_spike_data[i+32] = fc_flag || fetch_s_addr[0] ? sel_wb_spike_data[i*2 + 1] : sel_wb_spike_data[i + 32];
        end
    endgenerate

    assign sparse_spike_ren = spike_rd_en;
    assign sparse_spike_wen = wb_spike_en & ~acc_only_enable;
    assign sparse_spike_waddr = (spike_rd_en || ((~fetch_s_addr[0] & ~fc_flag))) ? wb_spike_internal_addr : wb_spike_addr; //wb_spike_addr;
    assign sram_w_data = pw_weight_wr_en ? {sram_r_data[63:40], updated_weight[7:0], sram_r_data[31:0]} : wb_mp_en ? (wb_mp_0 ? wb_mp_data[63:0] : wb_mp_data[127:64]) : real_wb_spike_data;
    
    // trace logic
    // integer trace_ref;
    // reg debug_wb_err;
    // reg [64+8-1:0] trace_data;
    
    // wire [8:0] compare_waddr = wb_spike_addr;
    // wire [63:0] compare_wdata = real_wb_spike_data;
    // wire [8:0] trace_waddr = trace_data[71:64];
    // wire [63:0] trace_wdata = trace_data[63:0];

    // initial begin
    //     trace_ref = $fopen("C:/Python_Project/HeiChips/Large_Tile/EEG_SIM/trace_w_addr_spike.txt", "r");
    // end

    // always @(posedge clk)
    //  begin 
    //      #1;
    //      if(wb_spike_en && (fetch_s_addr[0] ))//|| fc_flag
    //      begin
    //          $fscanf(trace_ref, "%h", trace_data);
    //      end
    //  end

    //  always @(posedge clk)
    //  begin
    //      #2;
    //      if(!rst_n)
    //      begin
    //          debug_wb_err <= 1'b0;
    //      end
    //      else if(wb_spike_en && (fetch_s_addr[0] ))//|| fc_flag
    //      begin
    //          if(compare_waddr != trace_waddr || compare_wdata != trace_wdata)  begin
    //              $display("--------------------------ERROR----------------------------");
    //              $finish;
    //          end 
    //      end
    //  end
    // integer trace_ref;
    // reg     debug_wb_err;
    // wire [255:0] compare_data = {pw_spike_data_t3, pw_spike_data_t2, pw_spike_data_t1, pw_spike_data_t0};
    // reg [255:0] trace_data;

    // initial begin
    //     trace_ref = $fopen("C:/Python_Project/HeiChips/SW/first_trace.txt", "r");
    // end
    // always @(posedge clk)
    //  begin 
    //      #1;
    //      if(spike_wb_en)
    //      begin
    //          $fscanf(trace_ref, "%h", trace_data);
    //      end
    //  end

    //  always @(posedge clk)
    //  begin
    //      #2;
    //      if(!rst_n)
    //      begin
    //          debug_wb_err <= 1'b0;
    //      end
    //      else if(spike_wb_en)
    //      begin
    //          if(compare_data != trace_data)  begin
    //              $display("--------------------------ERROR----------------------------");
    //              $finish;
    //          end 
    //      end
    //  end

endmodule