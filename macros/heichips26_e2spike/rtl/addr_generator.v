module ADDR_GENERATOR(
    input wire                                      clk                     ,
    // input wire rst_n,

    input wire  [8:0]                               base_weight_addr        ,
    input wire  [8:0]                               base_scale_addr         ,
    // input wire  [8:0] base_bias_addr,
    input wire  [8:0]                               base_mp_addr            ,

    // config: sparse (pointwise) core
    // input wire  [5:0] pw_output_channels,
    input wire  [8:0]                               base_pw_weight_addr     ,
    input wire  [8:0]                               base_pw_scale_addr      ,
    // input wire  [8:0] base_pw_bias_addr,
    input wire  [8:0]                               base_pw_mp_addr         ,
    
    input wire                                      dense_spike_fetch_done  ,
    input wire                                      dense_fetch_weight_en   ,
    input wire                                      dense_fetch_scale_en    ,
    input wire        dense_fetch_bias_en,
    input wire        dense_fetch_mp_en,
    input wire        dense_fetch_wb_mp_en,

    input wire        spike_one_pixel_valid,
    input wire        pw_weight_en,
    input wire        pw_scale_en,
    input wire        [1:0] combined_pw_bias_en,
    input wire        [1:0] combined_pw_mp_en,
    input wire        pw_wb_mp_en,

    input wire [8:0] sparse_spike_waddr,
    input wire        sparse_spike_wen,
    input wire        sparse_weight_wr_en,
    input wire [8:0] fetch_spike_sram_r_addr,
    input wire        fetch_spike_sram_ren,

    //out
    output wire       sram_ren,
    output wire       sram_wen,
    output wire [8:0] sram_r_addr,
    output wire [8:0] sram_w_addr,

    input wire        final_cls_layer,
    input wire        online_training_disable

);

    reg  [8:0] shared_r_addr;// dw-w, dw-b, pw-bias, pw-s,dw-r-mp,;
    reg  [8:0] dw_scale_addr;
    reg  [8:0] pw_weight_addr;
    reg  [8:0] shared_w_addr;

    wire       shared_en = dense_fetch_weight_en | dense_fetch_bias_en | pw_scale_en | 
                           (|combined_pw_bias_en);

    always@(posedge clk) begin
        if(dense_spike_fetch_done == 1'b1) begin
            shared_r_addr <= base_weight_addr;
        end
        else if(spike_one_pixel_valid == 1'b1) begin
            shared_r_addr <= base_pw_scale_addr;
        end
        // else if()
        else if(shared_en == 1'b1) begin
            begin
                shared_r_addr <= shared_r_addr + 1'b1;
            end
        end
    end

    always@(posedge clk) begin
        if(dense_spike_fetch_done == 1'b1) begin
            dw_scale_addr <= base_scale_addr;
        end
        else if(dense_fetch_scale_en == 1'b1) begin
            dw_scale_addr <= dw_scale_addr + 1'b1;
        end
    end

    always@(posedge clk) begin
        if(spike_one_pixel_valid == 1'b1) begin
            pw_weight_addr <= base_pw_weight_addr;
        end
        else if(pw_weight_en == 1'b1 && ~final_cls_layer) begin
            pw_weight_addr <= pw_weight_addr + 1'b1;
        end
        else if(pw_weight_en == 1'b1 && final_cls_layer && online_training_disable) begin
            pw_weight_addr <= pw_weight_addr + 1'b1;
        end
        else if(sparse_weight_wr_en == 1'b1) begin
            pw_weight_addr <= pw_weight_addr + 1'b1;
        end
    end


    ///////write address generator/////////
    always@(posedge clk) begin
        if(dense_spike_fetch_done == 1'b1) begin
            shared_w_addr <= base_mp_addr;
        end
        else if(spike_one_pixel_valid == 1'b1) begin
            shared_w_addr <= base_pw_mp_addr;
        end
        else if(dense_fetch_wb_mp_en == 1'b1 || pw_wb_mp_en == 1'b1) begin
            shared_w_addr <= shared_w_addr + 1'b1;
        end
    end

    // assign sram_r_addr = dense_fetch_mp_en ? shared_w_addr : shared_r_addr;
    // assign sram_w_addr = shared_w_addr;
    assign sram_ren = shared_en | dense_fetch_scale_en | pw_weight_en | dense_fetch_mp_en | fetch_spike_sram_ren | (|combined_pw_mp_en);
    assign sram_wen = dense_fetch_wb_mp_en | pw_wb_mp_en | sparse_spike_wen | sparse_weight_wr_en;
    assign sram_r_addr = dense_fetch_mp_en    ? shared_w_addr :
                     |combined_pw_mp_en   ? shared_w_addr + combined_pw_mp_en[0] :
                     dense_fetch_scale_en ? dw_scale_addr :
                     pw_weight_en         ? pw_weight_addr :
                     fetch_spike_sram_ren ? fetch_spike_sram_r_addr :
                                            shared_r_addr;
    assign sram_w_addr = sparse_spike_wen ? sparse_spike_waddr :
                         sparse_weight_wr_en ? pw_weight_addr :
                         shared_w_addr;

endmodule