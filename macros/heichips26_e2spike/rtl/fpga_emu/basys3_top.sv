`default_nettype none

module basys3_top (
    input  wire        clk,
    input  wire [15:0] sw,
    output wire [15:0] led,

    input  wire       btnC,
    input  wire       btnU,
    input  wire       btnL,
    input  wire       btnR,
    input  wire       btnD,
    input  wire [7:0] JA
);

    wire gbl_start;
    wire gbl_finish;
    wire class_label;
    wire [15:0] ui_in;
    wire [15:0] uo_out;
    wire [15:0] uio_in;
    wire [15:0] uio_out;
    wire [15:0] uio_oe;

    wire [9:0]  sram_addr;
    wire        sram_ren;
    wire [15:0] sram_r_data;
    wire        sram_wen;
    wire [15:0] sram_w_data;

    reg sw1_meta;
    reg sw1_sync;
    reg sw1_prev;

    // SW0: 0 = reset, 1 = run.
    // A rising edge on SW1 generates a one-clock start pulse.
    always @(posedge clk or negedge sw[0]) begin
        if (!sw[0]) begin
            sw1_meta <= 1'b0;
            sw1_sync <= 1'b0;
            sw1_prev <= 1'b0;
        end else begin
            sw1_meta <= sw[1];
            sw1_sync <= sw1_meta;
            sw1_prev <= sw1_sync;
        end
    end

    assign gbl_start = sw1_sync & ~sw1_prev;
    //assign sram_en = sram_ren | sram_wen;
    assign uio_in = {
        14'b0,
        sw[2],      // SW2=1: disable training; SW2=0: enable training
        gbl_start
    };

    mem_ctrl U_MEM_CTRL (
        .clk  (clk),
        .rst_n(sw[0]),
        .wen  (sram_wen),
        .ren  (sram_ren),
        .addr (sram_addr),
        .din  (sram_w_data),
        .dout (sram_r_data)
    );
        
    ila_1 U_ILA_START (
        .clk    (clk),
        .probe0 (uio_in[1])
    );
    
    
    
    assign ui_in  = sram_r_data;
//    assign uio_in = {
//        14'b0,
//        1'b1,       // uio_in[1]: disable online training
//        gbl_start   // uio_in[0]: one-cycle start pulse
//    };
    assign sram_addr = uio_out[9:0];
    assign sram_ren = uio_out[10];
    assign sram_wen = uio_out[11];
    assign gbl_finish = uio_out[12];
    assign class_label = uio_out[13];

    //in
//    assign uio_in[15:2] = 14'b0;

//    assign uio_in[0] = gbl_start;
//    assign uio_in[1] = online_training_disable;

    assign sram_w_data = uo_out;
//    assign ui_in = sram_r_data;
    
    
    
    heichips26_e2spike U_HEICHIPS26_E2SPIKE (
        .clk     (clk),
        .rst_n   (sw[0]),
        .ena     (1'b1),
        .ui_in   (ui_in),
        .uo_out  (uo_out),
        .uio_in  (uio_in),
        .uio_out (uio_out),
        .uio_oe  (uio_oe)
    );
//    micro_brain_top U_MICRO_BRAIN (
//        .clk         (clk),
//        .rst_n       (sw[0]),
//        .gbl_start   (gbl_start),
//        .gbl_finish  (gbl_finish),
//        .class_label (class_label),
//            .online_training_disable (1'b1),


//        .sram_addr   (sram_addr),
//        .sram_ren    (sram_ren),
//        .sram_r_data (sram_r_data),
//        .sram_wen    (sram_wen),
//        .sram_w_data (sram_w_data)
//    );
       
//    BANK_MEM_SIM U_BANK_MEM (
//        .clka  (clk),
//        .ena   (sram_en),
//        .wea   (sram_wen),
//        .addra (sram_addr),
//        .dina  (sram_w_data),
//        .douta (sram_r_data)
//    );

    // LED0: finish pulse, LED1: class, LED2: synchronized SW1.
    assign led = {
        13'd0,
        sw1_sync,
        class_label,
        gbl_finish
    };

    wire unused;
    assign unused = &{btnC, btnU, btnL, btnR, btnD, JA};

endmodule

`default_nettype wire
