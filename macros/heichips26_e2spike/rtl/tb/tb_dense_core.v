`timescale 1ns / 1ps

module tb_dense_core;

    reg clk;
    reg rst_n;
    reg [5:0] input_channels;
    reg row_has_two;
    reg [7:0] max_lenth;
    reg fetch_en;
    reg [7:0] fetch_s_addr;
    reg [7:0] fetch_e_addr;
    reg config_en;
    reg [8:0] base_weight_addr;
    reg [8:0] base_scale_addr;
    reg [8:0] base_bias_addr;
    reg [8:0] base_mp_addr;

    // DUT <-> SRAM
    wire [8:0]  sram_r_addr;
    wire        sram_ren;
    wire [63:0] sram_r_data;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 0;
        #10 rst_n = 1;
    end

    initial begin
        row_has_two = 1;
        input_channels = 4;
        max_lenth = 80;
        fetch_en = 0;
        fetch_s_addr = 8'hFF;
        fetch_e_addr = 8'h03;
        config_en = 0;
        base_weight_addr = 160;
        base_scale_addr = 168;
        base_bias_addr = 164;
        base_mp_addr = 496;
        #1000;

        @(posedge clk);
        config_en = 1;
        @(posedge clk);
        config_en = 0;
        
        #100;
        @(posedge clk);
        fetch_en = 1;
        @(posedge clk);
        fetch_en = 0;

        #5000;

        $finish;
    end

    DENSE_CORE U_DENSE_CORE (
        .clk                     (clk),
        .rst_n                   (rst_n),
        .input_channels          (input_channels),
        // fetch spike
        .fetch_spike_row_has_two (row_has_two),
        .fetch_spike_max_lenth   (max_lenth),
        .fetch_spike_fetch_en    (fetch_en),
        .fetch_spike_fetch_s_addr(fetch_s_addr),
        .fetch_spike_fetch_e_addr(fetch_e_addr),

        .config_en               (config_en),
        .base_weight_addr        (base_weight_addr),
        .base_scale_addr         (base_scale_addr),
        .base_bias_addr          (base_bias_addr),
        .base_mp_addr            (base_mp_addr),

        // SRAM read port
        .sram_r_addr             (sram_r_addr),
        .sram_ren                (sram_ren),
        .sram_r_data             (sram_r_data)
    );

    // bank A: low 32 bits, bank B: high 32 bits, shared address
    BANKA_MEM U_BANKA_MEM (
        .A_CLK  (clk),
        .A_MEN  (1'b1),
        .A_WEN  (1'b0),
        .A_REN  (sram_ren),
        .A_ADDR (sram_r_addr),
        .A_DIN  (32'd0),
        .A_BM   (32'd0),
        .A_DLY  (1'b0),
        .A_DOUT (sram_r_data[31:0])
    );

    BANKB_MEM U_BANKB_MEM (
        .A_CLK  (clk),
        .A_MEN  (1'b1),
        .A_WEN  (1'b0),
        .A_REN  (sram_ren),
        .A_ADDR ({1'b0, sram_r_addr}),
        .A_DIN  (32'd0),
        .A_BM   (32'd0),
        .A_DLY  (1'b0),
        .A_DOUT (sram_r_data[63:32])
    );

endmodule