module DENSE_CORE #(
    parameter RW_GAP_CYCLE = 2
)(
    input wire                                  clk                     ,
    input wire                                  rst_n                   ,

    // fetch spike
    input wire  [1:0]                           time_step               ,
    input wire  [7:0]                           mem_len_per_t           ,
    input wire  [5:0]                           input_channels          ,
    input wire                                  fetch_spike_row_has_two ,
    input wire  [7:0]                           fetch_spike_max_lenth   ,
    input wire                                  fetch_spike_fetch_en    ,
    input wire  [7:0]                           fetch_spike_fetch_s_addr,
    
    // send/from to sparse core
    input wire                                  shift_spike_from_sparse ,
    output wire [1:0]                           spike_one_pixel         ,
    output wire                                 spike_one_pixel_valid   ,

    // SRAM read port
    input  wire                                 sram_ren                ,
    input  wire                                 sram_wen                ,
    input  wire [63:0]                          sram_r_data             ,
    output wire [63:0]                          sram_w_data             ,

    // interaction between dual-mode PE
    output wire [31:0]                          dense_spikes            ,
    output wire                                 dense_inter_acc_en      ,
    output wire                                 dense_outer_acc_en      ,
    output wire                                 dense_scale_en          ,
    output wire                                 dense_bias_en           ,
    output wire                                 dense_mp_en             ,
    output wire                                 dense_spike_en          ,
    input  wire [7:0]                           spike_out               ,
    input  wire [63:0]                          wb_mp_data              ,

    // connect to addr generator
    output wire [8:0]                           fetch_spike_sram_r_addr ,
    output wire                                 fetch_spike_sram_ren    ,
    output wire                                 fetch_spike_sram_wen    ,
    output wire [63:0]                          fetch_spike_sram_w_data ,
    output wire                                 fetch_spike_fetch_done  ,
    output wire                                 dense_fetch_weight_en   ,
    output wire                                 dense_fetch_scale_en    ,
    output wire                                 dense_fetch_bias_en     ,
    output wire                                 dense_fetch_mp_en       ,
    output wire                                 dense_fetch_wb_mp_en    ,
    input wire [RW_GAP_CYCLE-1:0]               shift_for_mem_bit_trans  
    
);

    ////////////////////////////////// reg ////////////////////
    // calculation related signals
    reg                                         acc_en                  ;
    reg                                         scale_en                ;
    reg                                         bias_en                 ;
    reg                                         mp_en                   ;
    reg                                         spike_en                ;
    reg                                         wb_mp_en                ;
    reg                                         same_pixel_in_progress  ;
    reg  [3:0]                                  shift_cnt               ;
    reg                                         fetch_weight_en         ;
    reg                                         fetch_scale_en          ;
    reg                                         fetch_bias_en           ;
    reg                                         fetch_mp_en             ;
    reg  [63:0]                                 spike_one_t             ;
    ////////////////////////////////// wire ////////////////////
    wire                                        fetch_spike_shift_en    ;
    wire [31:0]                                 fetch_spike_pixel_out   ;
    wire [2:0]                                  input_channels_52_sub_1 ;
    wire [63:0]                                 tmp_reog                ;
    wire                                        dense_cal_done          ;
    
    FETCH_SPIKE #(
        .RW_GAP_CYCLE(RW_GAP_CYCLE)
    )U_FETCH_SPIKE (
        .clk(clk),
        .rst_n(rst_n),

        .time_step(time_step),
        .mem_len_per_t(mem_len_per_t),
        .row_has_two(fetch_spike_row_has_two),
        .max_lenth(fetch_spike_max_lenth),
        .fetch_en(fetch_spike_fetch_en),
        .fetch_s_addr(fetch_spike_fetch_s_addr),
        // .fetch_e_addr(fetch_spike_fetch_e_addr),
        .sram_r_addr(fetch_spike_sram_r_addr),
        .sram_ren(fetch_spike_sram_ren),
        .sram_r_data(sram_r_data),
        .sram_w_data(fetch_spike_sram_w_data),
        .sram_wen(fetch_spike_sram_wen),
        .fetch_done(fetch_spike_fetch_done),
        .shift_en(fetch_spike_shift_en),
        .pixel_out(fetch_spike_pixel_out),
        .shift_for_mem_bit_trans(shift_for_mem_bit_trans),
        .input_channels_52(input_channels[5:2]),
        .read_times(shift_cnt),
        .dense_cal_done(dense_cal_done)
    );

    assign input_channels_52_sub_1 = input_channels[5:2] - 1;
    always@(posedge clk or negedge rst_n) begin
        if(rst_n == 1'b0) begin
            same_pixel_in_progress <= 1'b0;
        end
        else if(fetch_spike_fetch_done == 1'b1) begin
            same_pixel_in_progress <= 1'b1;
        end
        else if(fetch_spike_shift_en && shift_cnt == input_channels_52_sub_1) begin
            same_pixel_in_progress <= 1'b0;
        end
    end

    always@(posedge clk or negedge rst_n) begin
        if(rst_n == 1'b0) begin
            shift_cnt <= 0;
        end
        else if(fetch_spike_fetch_en)begin
            shift_cnt <= 0;
        end
        else if(fetch_spike_shift_en == 1'b1) begin
            // if(shift_cnt == input_channels_52_sub_1) begin
            //     shift_cnt <= shift_cnt;
            // end
            // else 
            begin
                shift_cnt <= shift_cnt + 1'b1;
            end
        end
    end

    // match memory
    
    assign dense_fetch_weight_en = fetch_weight_en;
    assign dense_fetch_scale_en = fetch_scale_en;
    assign dense_fetch_bias_en = fetch_bias_en;
    assign dense_fetch_mp_en = fetch_mp_en;
    assign dense_fetch_wb_mp_en = wb_mp_en;

    reg [7:0] read_en_seq;

    always@(posedge clk or negedge rst_n) begin
        if(rst_n == 1'b0) begin
            read_en_seq <= 8'h0;
        end
        else if(sram_ren == 1'b1 || sram_wen == 1'b1) begin
            read_en_seq <= {wb_mp_en, fetch_spike_sram_ren, fetch_weight_en, fetch_scale_en, fetch_bias_en, fetch_mp_en};
        end
    end

    // weight rd
    assign fetch_spike_shift_en = fetch_weight_en;
    always@(posedge clk) begin
        if(fetch_spike_fetch_done == 1'b1) begin
            fetch_weight_en <= 1'b1;
        end
        // else if(shift_for_mem_bit_trans[RW_GAP_CYCLE-1] & read_en_seq[5]) begin//wb_mp_en && same_pixel_in_progress
        //     fetch_weight_en <= same_pixel_in_progress;
        // end
        else begin
            fetch_weight_en <= 0;
        end
    end
    
    // fetch scale
    reg fetch_weight_en_ff1;
    always@(posedge clk) begin
        if(shift_for_mem_bit_trans[RW_GAP_CYCLE-1] == 1'b1) begin
            fetch_weight_en_ff1 <= read_en_seq[3];
        end
        else begin
            fetch_weight_en_ff1 <= 0;
        end
    end
    
    always@(posedge clk) begin
        if(fetch_weight_en_ff1 == 1'b1) begin
            fetch_scale_en <= 1'b1;
        end
        else begin
            fetch_scale_en <= 0;
        end
    end
    
    // fetch bias
    always@(posedge clk) begin
        if(shift_for_mem_bit_trans[RW_GAP_CYCLE-1] == 1'b1) begin
            fetch_bias_en <= read_en_seq[2];
        end
        else begin
            fetch_bias_en <= 0;
        end
    end 
    
    // fetch mp
    always@(posedge clk) begin
        if(shift_for_mem_bit_trans[RW_GAP_CYCLE-1] == 1'b1) begin
            fetch_mp_en <= read_en_seq[1];
        end
        else begin
            fetch_mp_en <= 0;
        end
    end 

    always@(posedge clk) begin
        acc_en <= fetch_weight_en_ff1;

        scale_en <= shift_for_mem_bit_trans[RW_GAP_CYCLE-1] & read_en_seq[2];//acc_en;
        bias_en <= shift_for_mem_bit_trans[RW_GAP_CYCLE-1] & read_en_seq[1];//scale_en;
        mp_en <= shift_for_mem_bit_trans[RW_GAP_CYCLE-1] & read_en_seq[0];//bias_en;
        spike_en <= mp_en;
        wb_mp_en <= spike_en;
    end

    // // compute cores
    // wire [7:0] spike_out;
    // wire [63:0] wb_mp_data;
    // genvar i;
    // generate
    //     // fetch_spike_pixel_out[i+16], fetch_spike_pixel_out[i+16], fetch_spike_pixel_out[i+8],fetch_spike_pixel_out[i]
    //     for (i=0;i<4;i=i+1) begin : compute_core
    //         DPE U_DPE (
    //             .clk         (clk),
    //             .rst_n       (rst_n),
    //             .time_step   (time_step),
    //             .acc_en      (acc_en),
    //             .in_d        (fetch_spike_pixel_out[i*8 +: 8]),
    //             .in_w        (sram_r_data[i*16 +: 16]),
    //             .scale_en    (scale_en),
    //             .scale_value (sram_r_data[32+i*8 +: 8]),
    //             .bias_en     (bias_en),
    //             .bias_value  (sram_r_data[i*16 +: 16]),
    //             .mp_en       (mp_en),
    //             .mp_value    (sram_r_data[i*16 +: 16]),
    //             .spike_en    (spike_en),

    //             .spike_out   (spike_out[i*2 +: 2]), //open
    //             .wb_mp       (wb_mp_data[i*16 +: 16])  //open
    //         );

    //     end
    // endgenerate

    assign dense_spikes = fetch_spike_pixel_out;
    assign dense_inter_acc_en = fetch_weight_en_ff1;
    assign dense_outer_acc_en = acc_en;
    assign dense_scale_en = scale_en;
    assign dense_bias_en = bias_en;
    assign dense_mp_en = mp_en;
    assign dense_spike_en = spike_en;

    assign sram_w_data = wb_mp_data;

    // output spike


    always@(posedge clk)begin
        if(wb_mp_en == 1'b1) begin
           spike_one_t <= {spike_out, spike_one_t[63:8]};
        end
        else if(spike_one_pixel_valid)begin
            spike_one_t <= tmp_reog;
        end
        else if(shift_spike_from_sparse) begin
            spike_one_t <= {spike_one_pixel, spike_one_t[63:2]};
        end
    end

    reg wb_mp_en_ff1;
    always@(posedge clk) begin
        wb_mp_en_ff1 <= shift_for_mem_bit_trans[RW_GAP_CYCLE-1] & read_en_seq[5];//wb_mp_en;
    end
    assign spike_one_pixel_valid = wb_mp_en_ff1 & ~same_pixel_in_progress;//same_pixel_in_progress_ff1 & ~same_pixel_in_progress;
    assign dense_cal_done = wb_mp_en_ff1;
    assign tmp_reog = fetch_spike_row_has_two ? {spike_one_t[63:32], spike_one_t[63:32]} : spike_one_t;
    assign spike_one_pixel = spike_one_t[1:0];

endmodule