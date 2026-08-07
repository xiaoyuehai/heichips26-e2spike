module micro_brain_top(
    input wire  clk,
    input wire  rst_n,
    input wire  gbl_start,
    output wire gbl_finish,
    output wire class_label,
    input wire  online_training_disable,
    // physical SRAM port (single 1024x32 macro)
    output wire [9:0]  sram_addr,
    output wire        sram_ren,
    input  wire [15:0]  sram_r_data,
    output wire        sram_wen,
    output wire [15:0]  sram_w_data
);

    // CORE_TOP side: logical 512x64 view
    wire [8:0]  core_sram_r_addr;
    wire        core_sram_ren;
    wire [63:0] core_sram_r_data;
    wire [8:0]  core_sram_w_addr;
    wire        core_sram_wen;
    wire [63:0] core_sram_w_data;

    // NN_CTRL <-> CORE_TOP config
    wire [8:0] base_weight_addr;
    // wire [8:0] base_bias_addr;
    // wire [8:0] base_pw_bias_addr;
    wire [8:0] base_pw_scale_addr;
    wire [8:0] base_scale_addr;
    wire [8:0] base_pw_weight_addr;
    wire [8:0] base_mp_addr;
    wire [8:0] base_pw_mp_addr;

    wire       row_has_two;
    wire [7:0] mem_len_per_t;
    wire [7:0] max_lenth;
    wire [5:0] input_channels;
    wire [5:0] pw_output_channels;
    wire       final_cls_layer;

    // NN_CTRL <-> CORE_TOP handshake
    wire       ds_block_start;
    wire       ds_block_end;
    wire       fc_start;
    wire       fc_finish;
    wire [8:0] rd_inst_addr;
    wire       rd_inst_en;
    wire       rw_ready;

    NN_CTRL U_NN_CTRL(
        .clk                 (clk),
        .rst_n               (rst_n),

        .gbl_start           (gbl_start),
        .gbl_finish          (gbl_finish),

        .base_weight_addr    (base_weight_addr),
        // .base_bias_addr      (base_bias_addr),
        // .base_pw_bias_addr   (base_pw_bias_addr),
        .base_pw_scale_addr  (base_pw_scale_addr),
        .base_scale_addr     (base_scale_addr),
        .base_pw_weight_addr (base_pw_weight_addr),
        .base_mp_addr        (base_mp_addr),
        .base_pw_mp_addr     (base_pw_mp_addr),

        .row_has_two         (row_has_two),
        .mem_len_per_t       (mem_len_per_t),
        .max_lenth           (max_lenth),
        .input_channels      (input_channels),
        .pw_output_channels  (pw_output_channels),
        .final_cls_layer     (final_cls_layer),
        .ds_block_start      (ds_block_start),
        .ds_block_end        (ds_block_end),
        .fc_start            (fc_start),
        .fc_finish           (fc_finish),
        .rd_inst_addr        (rd_inst_addr),
        .rd_inst_en          (rd_inst_en),
        .rd_inst_data        (core_sram_r_data[63:32]),
        .rw_ready            (rw_ready)
    );

    CORE_TOP U_CORE_TOP(
        .clk                     (clk),
        .rst_n                   (rst_n),

        .ds_block_start          (ds_block_start),
        .ds_block_end            (ds_block_end),
        .fc_start                (fc_start),
        .fc_finish               (fc_finish),
        .final_cls_layer         (final_cls_layer),

        // fetch spike
        .input_channels          (input_channels),
        .mem_len_per_t           (mem_len_per_t),
        .fetch_spike_row_has_two (row_has_two),
        .fetch_spike_max_lenth   (max_lenth),

        .config_en               (ds_block_start),
        .base_weight_addr        (base_weight_addr),
        .base_scale_addr         (base_scale_addr),
        // .base_bias_addr          (base_bias_addr),
        .base_mp_addr            (base_mp_addr),

        // config: sparse (pointwise) core
        .pw_output_channels      (pw_output_channels),
        .base_pw_weight_addr     (base_pw_weight_addr),
        .base_pw_scale_addr      (base_pw_scale_addr),
        // .base_pw_bias_addr       (base_pw_bias_addr),
        .base_pw_mp_addr         (base_pw_mp_addr),

        .class_label             (class_label),

        // logical 512x64 SRAM port
        .sram_r_addr             (core_sram_r_addr),
        .sram_ren                (core_sram_ren),
        .sram_r_data             (core_sram_r_data),
        .sram_w_addr             (core_sram_w_addr),
        .sram_wen                (core_sram_wen),
        .sram_w_data             (core_sram_w_data),
        .rw_ready                (rw_ready),
        .rd_inst_en              (rd_inst_en),
        .online_training_disable (online_training_disable),
        .gbl_start               (gbl_start)
    );

    MEM_BIT_TRANS U_MEM_BIT_TRANS (
        .clk         (clk),
        .rst_n       (rst_n),

        // core side
        .sram_ren    (core_sram_ren || rd_inst_en),
        .sram_r_addr (rd_inst_en ? rd_inst_addr : core_sram_r_addr),
        .sram_wen    (core_sram_wen),
        .sram_w_addr (core_sram_w_addr),
        .sram_w_data (core_sram_w_data),
        .o_rdata     (core_sram_r_data),

        // physical side
        .o_addr      (sram_addr),
        .o_ren       (sram_ren),
        .sram_r_data (sram_r_data),
        .o_wen       (sram_wen),
        .o_wdata     (sram_w_data)
    );

endmodule
