module heichips26_e2spike (
    input  wire [15:0] ui_in,    // Dedicated inputs
    output wire [15:0] uo_out,   // Dedicated outputs
    
    output wire [15:0] uio_out,  // IOs: Output path

    input  wire [15:0] uio_in,   // IOs: Input path
    output wire [15:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // All output pins must be assigned. If not used, assign to 0.
//   assign uo_out  = ui_in + uio_in;  // Example: ou_out is the sum of ui_in and uio_in
//   assign uio_out = 0;
//   assign uio_oe  = 0;

//   // List all unused inputs to prevent warnings
//   wire _unused = &{ena, clk, rst_n, 1'b0};

    wire gbl_start;
    wire gbl_finish;
    wire class_label;
    wire [9:0] sram_addr;
    wire sram_ren;
    wire [15:0] sram_r_data;
    wire sram_wen;
    wire [15:0] sram_w_data;

    micro_brain_top U_MICRO_BRAIN_TOP(
        .clk         (clk),
        .rst_n       (rst_n),
        .gbl_start   (gbl_start),
        .gbl_finish  (gbl_finish),
        .class_label (class_label),
        .sram_addr   (sram_addr),
        .sram_ren    (sram_ren),
        .sram_r_data (sram_r_data),
        .sram_wen    (sram_wen),
        .sram_w_data (sram_w_data)
    );

    // sram read data
    assign sram_r_data = ui_in; // 16 bits

    // sram write data
    assign uo_out = sram_w_data; // 16 bits

    // sram address
    assign uio_out[9:0] = sram_addr[9:0]; // 10 bits
    assign uio_out[10] = sram_ren;
    assign uio_out[11] = sram_wen;
    assign uio_out[12] = gbl_finish;
    assign uio_out[13] = class_label;// 2 pins
    assign uio_out[14] = 1'b0;
    assign uio_out[15] = 1'b0;

    assign gbl_start = uio_in[0];

    assign uio_oe = 16'h0000;
    wire _unused = &{uio_in[15:1], ena};



endmodule