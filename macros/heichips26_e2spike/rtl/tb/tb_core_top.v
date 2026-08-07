`timescale 1ns / 1ps

module tb_core_top;

    reg clk;
    reg rst_n;
    reg [5:0] input_channels;
    wire pixel_all_t_done;
    reg row_has_two;
    reg [7:0] max_lenth;
    reg pixel_start;
    reg [7:0] fetch_s_addr;
    reg [7:0] fetch_e_addr;
    reg config_en;
    reg [8:0] base_weight_addr;
    reg [8:0] base_scale_addr;
    reg [8:0] base_bias_addr;
    reg [8:0] base_mp_addr;
    reg [5:0] pw_output_channels;
    reg [8:0] base_pw_weight_addr;
    reg [8:0] base_pw_scale_addr;
    reg [8:0] base_pw_bias_addr;
    reg [8:0] base_pw_mp_addr;
    reg final_cls_layer;

    // DUT <-> SRAM
    wire [8:0]  sram_r_addr;
    wire        sram_ren;
    wire [63:0] sram_r_data;
    wire [8:0]  sram_w_addr;
    wire        sram_wen;
    wire [63:0] sram_w_data;
    reg [7:0] mem_len_per_t;
    reg ds_block_start;
    wire ds_block_end;
    reg fc_start;
    wire fc_finish;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 0;
        #10 rst_n = 1;
    end

    initial begin
        
        pixel_start = 0;
        fetch_s_addr = 8'hFF;
        // fetch_e_addr = 8'h03;
        config_en = 0;
        fc_start = 0;
        final_cls_layer = 0;

        // ds_block 1
        base_weight_addr = 160;
        base_bias_addr = 164; 
        base_pw_bias_addr = 168;
        base_pw_scale_addr = 176;

        base_scale_addr = 232;
        base_pw_weight_addr = 232;
        base_mp_addr = 496;
        base_pw_mp_addr = 504;
        
        row_has_two = 1;
        mem_len_per_t = 40;
        max_lenth = 80;
        input_channels = 16;
        pw_output_channels = 32;
        #1000;

        @(posedge clk);
        config_en = 1;
        @(posedge clk);
        config_en = 0;
        
        #100;
        @(posedge clk);
        ds_block_start = 1;
        @(posedge clk);
        ds_block_start = 0;

        wait(ds_block_end == 1'b1);

        #1000;
        // ds_block 2
        base_weight_addr = 180;
        base_bias_addr = 188; 
        base_pw_bias_addr = 196;
        base_pw_scale_addr = 204;

        base_scale_addr = 236;
        base_pw_weight_addr = 296;

        base_mp_addr = 496;
        base_pw_mp_addr = 504;
        
        row_has_two = 0;
        mem_len_per_t = 40;
        max_lenth = 40;
        input_channels = 32;
        pw_output_channels = 32;
        #100;
        @(posedge clk);
        ds_block_start = 1;
        @(posedge clk);
        ds_block_start = 0;

        wait(ds_block_end == 1'b1);

        #1000;

        // ds_block 3
        base_weight_addr = 208;
        base_bias_addr = 216; 
        base_pw_bias_addr = 224;
        base_pw_scale_addr = 228;

        base_scale_addr = 244;
        base_pw_weight_addr = 424;

        base_mp_addr = 496;
        base_pw_mp_addr = 504;
        
        row_has_two = 0;
        mem_len_per_t = 40;
        max_lenth = 20;
        input_channels = 32;
        pw_output_channels = 16;
        #100;
        @(posedge clk);
        ds_block_start = 1;
        @(posedge clk);
        ds_block_start = 0;

        wait(ds_block_end == 1'b1);

        #1000;

        // fc1
        // base_weight_addr = 180;
        // base_bias_addr = 188; 
        base_pw_bias_addr = 510;
        base_pw_scale_addr = 230;

        // base_scale_addr = 236;
        base_pw_weight_addr = 252;

        // base_mp_addr = 496;
        base_pw_mp_addr = 504;
        
        row_has_two = 0;
        mem_len_per_t = 40;
        max_lenth = 40;
        input_channels = 16;
        pw_output_channels = 8;
        @(posedge clk);
        fc_start = 1;
        @(posedge clk);
        fc_start = 0;

        wait(fc_finish == 1'b1);

        // fc2
        // base_weight_addr = 180;
        // base_bias_addr = 188; 
        base_pw_bias_addr = 510;
        base_pw_scale_addr = 231;

        // base_scale_addr = 236;
        base_pw_weight_addr = 268;

        // base_mp_addr = 496;
        base_pw_mp_addr = 504;
        
        row_has_two = 0;
        mem_len_per_t = 40;
        max_lenth = 40;
        input_channels = 8;
        pw_output_channels = 8;
        final_cls_layer = 1;
        @(posedge clk);
        fc_start = 1;
        @(posedge clk);
        fc_start = 0;

        wait(fc_finish == 1'b1);

        #1000;

        $finish;
    end

    CORE_TOP U_CORE_TOP (
        .clk                     (clk),
        .rst_n                   (rst_n),
        .fc_start                (fc_start),
        .fc_finish               (fc_finish),
        .final_cls_layer         (final_cls_layer),
        // .pixel_start             (pixel_start),
        // .pixel_all_t_done        (pixel_all_t_done),
        .ds_block_start          (ds_block_start),
        .ds_block_end            (ds_block_end),
        .mem_len_per_t           (mem_len_per_t),
        .input_channels          (input_channels),
        // fetch spike
        .fetch_spike_row_has_two (row_has_two),
        .fetch_spike_max_lenth   (max_lenth),
        // .fetch_spike_fetch_en    (fetch_en),
        // .fetch_spike_fetch_s_addr(fetch_s_addr),
        // .fetch_spike_fetch_e_addr(fetch_e_addr),

        .config_en               (config_en),
        .base_weight_addr        (base_weight_addr),
        .base_scale_addr         (base_scale_addr),
        .base_bias_addr          (base_bias_addr),
        .base_mp_addr            (base_mp_addr),

        .pw_output_channels      (pw_output_channels),
        .base_pw_weight_addr     (base_pw_weight_addr),
        .base_pw_scale_addr      (base_pw_scale_addr),
        .base_pw_bias_addr       (base_pw_bias_addr),
        .base_pw_mp_addr         (base_pw_mp_addr),

        // SRAM port
        .sram_r_addr             (sram_r_addr),
        .sram_ren                (sram_ren),
        .sram_r_data             (sram_r_data),
        .sram_w_addr             (sram_w_addr),
        .sram_wen                (sram_wen),
        .sram_w_data             (sram_w_data)
    );

    // bank A: low 32 bits, bank B: high 32 bits, shared address
    // banks have a single address port, so read/write share it (write wins,
    // DUT never issues read and write in the same cycle)
    wire [8:0] bank_addr = sram_wen ? sram_w_addr : sram_r_addr;

    BANKA_MEM U_BANKA_MEM (
        .A_CLK  (clk),
        .A_MEN  (1'b1),
        .A_WEN  (sram_wen),
        .A_REN  (sram_ren),
        .A_ADDR (bank_addr),
        .A_DIN  (sram_w_data[31:0]),
        .A_BM   (32'd0),
        .A_DLY  (1'b0),
        .A_DOUT (sram_r_data[31:0])
    );

    BANKB_MEM U_BANKB_MEM (
        .A_CLK  (clk),
        .A_MEN  (1'b1),
        .A_WEN  (sram_wen),
        .A_REN  (sram_ren),
        .A_ADDR ({1'b0, bank_addr}),
        .A_DIN  (sram_w_data[63:32]),
        .A_BM   (32'd0),
        .A_DLY  (1'b0),
        .A_DOUT (sram_r_data[63:32])
    );

endmodule