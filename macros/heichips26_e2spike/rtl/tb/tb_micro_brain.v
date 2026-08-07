`timescale 1ns / 1ps

module tb_micro_brain();

    reg clk;
    reg rst_n;
    reg gbl_start;
    wire gbl_finish;
    wire class_label;

    // DUT <-> physical SRAM (single 1024x32 macro)
    wire [9:0]  sram_addr;
    wire        sram_ren;
    wire [31:0] sram_r_data;
    wire        sram_wen;
    wire [31:0] sram_w_data;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 0;
        gbl_start = 0;
        #25;
        rst_n = 1;
        #100;
        @(posedge clk);
        gbl_start = 1;
        @(posedge clk);
        gbl_start = 0;

        wait(gbl_finish == 1'b1);
        $display("gbl_finish = %b", gbl_finish);
        $display("class_label = %b", class_label);
        #1000;
        $finish;
    end

    micro_brain_top U_DUT (
        .clk         (clk),
        .rst_n       (rst_n),
        .gbl_start   (gbl_start),
        .gbl_finish  (gbl_finish),
        .online_training_disable (1'b0),
        .class_label (class_label),

        .sram_addr   (sram_addr),
        .sram_ren    (sram_ren),
        .sram_r_data (sram_r_data),
        .sram_wen    (sram_wen),
        .sram_w_data (sram_w_data)
    );

    // single 1024x32 macro: low-word plane at 0..511, high-word plane at 512..1023

    // BANK_MEM_SIM U_BANK_MEM (
    //     .A_CLK  (clk),
    //     .rst_n  (rst_n),
    //     .A_MEN  (1'b1),
    //     .A_WEN  (sram_wen),
    //     .A_REN  (sram_ren),
    //     .A_ADDR (sram_addr),
    //     .A_DIN  (sram_w_data),
    //     .A_BM   (32'd0),
    //     .A_DLY  (1'b0),
    //     .A_DOUT (sram_r_data)
    // );

    mem_ctrl U_MEM_CTRL(
        .clk      (clk),
        .rst_n    (rst_n),
        .wen      (sram_wen),
        .ren      (sram_ren),
        .addr     (sram_addr),
        .din      (sram_w_data),
        .dout     (sram_r_data)
    );

endmodule
