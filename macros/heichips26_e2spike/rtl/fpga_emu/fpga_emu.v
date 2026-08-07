module FPGA_EMU(
    input wire clk_p,
    input wire clk_n,
    input wire rst_n,
    output wire gbl_finish,
    output wire class_label
);

    wire clk;
    wire locked;

    clk_wiz_0 U_CLK_WIZ (
        // Clock out ports
        .clk_out1  (clk),
        .locked    (locked),
        // Clock in ports
        .clk_in1_p (clk_p),
        .clk_in1_n (clk_n)
    );

    // hold design in reset until MMCM locks
    wire sys_rst_n = rst_n & locked;

    // gbl_start: one-cycle pulse on VIO probe rising edge (toggle 0->1 in VIO GUI)
    wire probe_out0;
    reg  probe_out0_reg;
    always@(posedge clk) begin
        probe_out0_reg <= probe_out0;
    end
    wire gbl_start = probe_out0 && ~probe_out0_reg;

    vio_0 U_VIO (
        .clk        (clk),
        .probe_out0 (probe_out0)
    );

    // DUT <-> BRAM
    wire [8:0]  sram_addr;
    wire        sram_ren;
    wire [63:0] sram_r_data;
    wire        sram_wen;
    wire [63:0] sram_w_data;

    micro_brain_top U_MICRO_BRAIN (
        .clk         (clk),
        .rst_n       (sys_rst_n),
        .gbl_start   (gbl_start),
        .gbl_finish  (gbl_finish),
        .class_label (class_label),

        .sram_addr   (sram_addr),
        .sram_ren    (sram_ren),
        .sram_r_data (sram_r_data),
        .sram_wen    (sram_wen),
        .sram_w_data (sram_w_data)
    );

    mem_ctrl U_MEM_CTRL(
        .clk      (clk),
        .rst_n    (rst_n),
        .wen      (sram_wen),
        .ren      (sram_ren),
        .addr     (sram_addr),
        .din      (sram_w_data),
        .dout     (sram_r_data)
    );

    // bank A: low 32 bits, bank B: high 32 bits, shared address
    // BRAM enable must be high for both read and write accesses
    wire bank_en = sram_ren | sram_wen;

    BANKA_MEM U_BANKA_MEM (
        .clka  (clk),
        .ena   (bank_en),
        .wea   (sram_wen),
        .addra (sram_addr),
        .dina  (sram_w_data[31:0]),
        .douta (sram_r_data[31:0])
    );

    BANKB_MEM U_BANKB_MEM (
        .clka  (clk),
        .ena   (bank_en),
        .wea   (sram_wen),
        .addra (sram_addr),
        .dina  (sram_w_data[63:32]),
        .douta (sram_r_data[63:32])
    );

endmodule
