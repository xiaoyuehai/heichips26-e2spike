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

    wire [15:0] ui_in;    // Dedicated inputs
    wire [15:0] uo_out;   // Dedicated outputs
    wire [15:0] uio_out;  // IOs: Output path
    wire [15:0] uio_in;   // IOs: Input path
    wire [15:0] uio_oe;   // IOs: Enable path (active high: 0=input, 1=output)
    wire       ena;      // always 1 when the design is powered, so you can ignore it

    heichips26_e2spike U_HEICHIPS26_E2SPIKE(
        .clk      (clk),
        .rst_n    (rst_n),
        .ena      (ena),
        .ui_in    (ui_in),
        .uo_out   (uo_out),
        .uio_out  (uio_out),
        .uio_in   (uio_in),
        .uio_oe   (uio_oe)
    );

    assign sram_addr = uio_out[9:0];
    assign sram_ren = uio_out[10];
    assign sram_wen = uio_out[11];
    assign gbl_finish = uio_out[12];
    assign class_label = uio_out[13];

    //in
    assign uio_in[0] = gbl_start;
    assign uio_in[1] = online_training_disable;

    assign sram_w_data = uo_out;
    assign ui_in = sram_r_data;
    /// UART

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
