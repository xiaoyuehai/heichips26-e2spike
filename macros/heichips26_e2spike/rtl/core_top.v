module CORE_TOP#(
    parameter RW_GAP_CYCLE = 5
)(
    input wire  clk,
    input wire  rst_n,
    
    // input wire  pixel_start,
    // output wire pixel_all_t_done,
    input wire ds_block_start,
    output wire ds_block_end,
    input wire fc_start,
    output wire fc_finish,
    input  wire final_cls_layer,
    input wire  cmp_mode,// 0: dense; 1: sparse;

    // fetch spike
    input wire  [5:0] input_channels,
    input wire  [7:0] mem_len_per_t,
    input wire        fetch_spike_row_has_two,
    input wire  [7:0] fetch_spike_max_lenth,
    // input wire        fetch_spike_fetch_en,
    // input wire  [7:0] fetch_spike_fetch_s_addr,
    // input wire  [7:0] fetch_spike_fetch_e_addr,

    // config: dense (depthwise) core
    input wire        config_en,
    input wire  [8:0] base_weight_addr,
    input wire  [8:0] base_scale_addr,
    // input wire  [8:0] base_bias_addr,
    input wire  [8:0] base_mp_addr,

    // config: sparse (pointwise) core
    input wire  [5:0] pw_output_channels,
    input wire  [8:0] base_pw_weight_addr,
    input wire  [8:0] base_pw_scale_addr,
    // input wire  [8:0] base_pw_bias_addr,
    input wire  [8:0] base_pw_mp_addr,

    output wire class_label,

    // SRAM port (shared, dense core has priority)
    output wire [8:0]  sram_r_addr,
    output wire        sram_ren,
    input  wire [63:0] sram_r_data,
    output wire [8:0]  sram_w_addr,
    output wire        sram_wen,
    output wire [63:0] sram_w_data,

    output wire        rw_ready,
    input wire        rd_inst_en,
    input wire        online_training_disable,
    input wire        gbl_start
);

    // dense <-> sparse handshake
    wire [1:0] spike_one_pixel;
    wire       spike_one_pixel_valid;
    wire       shift_spike_from_sparse;
    wire       fc_in_computing;
    wire       acc_only_enable;
    wire       fc_spike_vld;
    wire [1:0] fc_spike_data;
    wire [8:0] sram_r_addr_fc;
    wire       sram_ren_fc;
    wire       fc_wb_spike_en;
    wire       fc_wb_spike_finish;
    // wire [63:0] sram_r_data_fc;

    // dense/sparse write data (write enable/address come from ADDR_GENERATOR)
    wire [63:0] dense_sram_w_data;
    wire [63:0] sparse_sram_w_data;

    // dense core -> addr generator
    wire [8:0]  fetch_spike_sram_r_addr;
    wire        fetch_spike_sram_ren;
    wire        fetch_spike_fetch_done;
    wire        dense_fetch_weight_en;
    wire        dense_fetch_scale_en;
    wire        dense_fetch_bias_en;
    wire        dense_fetch_mp_en;
    wire        dense_fetch_wb_mp_en;

    // sparse core -> addr generator
    wire        pw_weight_en;
    wire        pw_scale_en;
    wire [1:0]  combined_bias_rd_en;
    wire [1:0]       combined_pw_mp_en;
    wire        pw_wb_mp_en;
    wire [8:0]  sparse_spike_waddr;
    wire        sparse_spike_wen;
    wire        sparse_spike_ren;

    // addr generator -> global SRAM port
    wire        ag_sram_ren;
    wire        ag_sram_wen;
    wire [8:0]  ag_sram_r_addr;
    wire [8:0]  ag_sram_w_addr;

    wire pixel_finish;
    wire fetch_spike_fetch_en;
    wire [1:0] time_step;
    wire global_set_enable;
    wire pixel_start;
    wire [7:0] fetch_s_addr;
    wire pixel_all_t_done;
    wire spike_wb_en;
    wire spike_wb_finish;
    wire fc_first_pixel_one_t;
    wire [1:0] fc_time_step;
    reg [RW_GAP_CYCLE-1:0] shift_for_mem_bit_trans;

    // pixel-valid as seen by sparse core / addr generator (FC mode muxed in)
    wire sparse_pixel_valid = fc_in_computing ? fc_spike_vld : spike_one_pixel_valid;

    // dense core <-> PE array
    wire [31:0] dense_spikes;
    wire        dense_inter_acc_en;
    wire        dense_outer_acc_en;
    wire        dense_scale_en;
    wire        dense_bias_en;
    wire        dense_mp_en;
    wire        dense_spike_en;

    // sparse core <-> PE array
    wire        sparse_mp_clr;
    wire [1:0]  sparse_act;
    wire        sparse_acc_en;
    wire        sparse_scale_en;
    wire [1:0]  sparse_bias_en;
    wire [1:0]  sparse_mp_en;
    wire        sparse_spike_en;
    wire [15:0] pooling_input;
    wire [15:0] pooling_output;

    // PE array results
    wire [15:0]  pe_spike_out;
    wire [127:0] pe_wb_mp_data;
    wire [63:0]  fetch_spike_sram_w_data;
    wire        fetch_spike_sram_wen;
    wire [7:0]  updated_weight;
    wire        pw_weight_wr_en;

    TOP_CTRL U_TOP_CTRL (
        .clk                     (clk),
        .rst_n                   (rst_n),
        .ds_block_start          (ds_block_start),
        .ds_block_end            (ds_block_end),
        .max_lenth               (fetch_spike_max_lenth), //input length
        .global_set_enable       (global_set_enable),
        .pixel_start             (pixel_start),
        .fetch_s_addr            (fetch_s_addr),
        .pixel_all_t_done        (pixel_all_t_done)//,
        // .spike_wb_en             (spike_wb_en),
        // .spike_wb_finish         (spike_wb_finish)
    );

    FC_CTRL #(
        .RW_GAP_CYCLE(RW_GAP_CYCLE)
    )U_FC_CTRL (
        .clk                     (clk),
        .rst_n                   (rst_n),

        .fc_start                (fc_start),
        .fc_finish               (fc_finish),
        .pixel_finish            (pixel_finish),
        .final_cls_layer         (final_cls_layer),
        .lenth_for_after_avg_pooling (final_cls_layer ? 4'd1 : 4'd10),
        .mem_len_per_t           (mem_len_per_t),

        .fc_spike_vld            (fc_spike_vld),
        // .fc_spike_data           (fc_spike_data),
        // .shift_spike_from_sparse (shift_spike_from_sparse),

        // SRAM read port
        .sram_r_addr             (sram_r_addr_fc),
        .sram_ren                (sram_ren_fc),
        // .sram_r_data             (sram_r_data),

        //fc special output
        .fc_in_computing         (fc_in_computing),
        .acc_only_enable         (acc_only_enable),
        .fc_first_pixel_one_t    (fc_first_pixel_one_t),
        .fc_time_step            (fc_time_step),
        .fc_wb_spike_en          (fc_wb_spike_en),
        .fc_wb_spike_finish      (spike_wb_finish),
        .shift_for_mem_bit_trans (shift_for_mem_bit_trans)
    );
    TS_CTRL U_TS_CTRL (
        .clk                     (clk),
        .rst_n                   (rst_n),
        .pixel_start             (pixel_start),
        .pixel_finish            (pixel_finish),
        .fetch_en                (fetch_spike_fetch_en),
        .time_step               (time_step),
        .pixel_all_t_done        (pixel_all_t_done),
        .spike_wb_en             (spike_wb_en),
        .spike_wb_finish         (spike_wb_finish)
    ); 

    DENSE_CORE #(
        .RW_GAP_CYCLE(RW_GAP_CYCLE)
    )U_DENSE_CORE (
        .clk                     (clk),
        .rst_n                   (rst_n),

        // fetch spike
        .time_step               (time_step),
        .mem_len_per_t           (mem_len_per_t),
        .input_channels          (input_channels),
        .fetch_spike_row_has_two (fetch_spike_row_has_two),
        .fetch_spike_max_lenth   (fetch_spike_max_lenth),
        .fetch_spike_fetch_en    (fetch_spike_fetch_en),
        .fetch_spike_fetch_s_addr(fetch_s_addr),
        // .fetch_spike_fetch_e_addr(),

        // .config_en               (config_en),
        // .base_weight_addr        (base_weight_addr),
        // .base_scale_addr         (base_scale_addr),
        // .base_bias_addr          (base_bias_addr),
        // .base_mp_addr            (base_mp_addr),

        // send/from to sparse core
        .shift_spike_from_sparse (shift_spike_from_sparse),
        .spike_one_pixel         (spike_one_pixel),
        .spike_one_pixel_valid   (spike_one_pixel_valid),

        // SRAM port (global ren/wen fed back for the beat trackers)
        .sram_ren                (sram_ren),
        .sram_r_data             (sram_r_data),
        .sram_wen                (sram_wen),
        .sram_w_data             (dense_sram_w_data),

        // dual-mode PE array
        .dense_spikes            (dense_spikes),
        .dense_inter_acc_en      (dense_inter_acc_en),
        .dense_outer_acc_en      (dense_outer_acc_en),
        .dense_scale_en          (dense_scale_en),
        .dense_bias_en           (dense_bias_en),
        .dense_mp_en             (dense_mp_en),
        .dense_spike_en          (dense_spike_en),
        .spike_out               (pe_spike_out[15:8]),
        // dense results live in the upper half of the array (PE4..7)
        .wb_mp_data              (pe_wb_mp_data[127:64]),

        // connect to addr generator
        .fetch_spike_sram_r_addr (fetch_spike_sram_r_addr),
        .fetch_spike_sram_ren    (fetch_spike_sram_ren),
        .fetch_spike_sram_wen    (fetch_spike_sram_wen),
        .fetch_spike_sram_w_data (fetch_spike_sram_w_data),
        .fetch_spike_fetch_done  (fetch_spike_fetch_done),
        .dense_fetch_weight_en   (dense_fetch_weight_en),
        .dense_fetch_scale_en    (dense_fetch_scale_en),
        .dense_fetch_bias_en     (dense_fetch_bias_en),
        .dense_fetch_mp_en       (dense_fetch_mp_en),
        .dense_fetch_wb_mp_en    (dense_fetch_wb_mp_en),
        .shift_for_mem_bit_trans (shift_for_mem_bit_trans)
    );

    SPARSE_CORE #(
        .RW_GAP_CYCLE(RW_GAP_CYCLE)
    )U_SPARSE_CORE (
        .clk                     (clk),
        .rst_n                   (rst_n),
        .final_cls_layer         (final_cls_layer),
        .time_step               (fc_in_computing ? fc_time_step : time_step),
        .pixel_start             (pixel_start),
        .global_set_enable       (global_set_enable),
        .pixel_finish            (pixel_finish),
        .spike_wb_en             (spike_wb_en || fc_wb_spike_en),
        .spike_wb_finish         (spike_wb_finish),
        .ds_block_start          (ds_block_start),
        .mem_len_per_t           (mem_len_per_t),
        // data from dense core (conv mode) or FC_CTRL (fc mode)
        .spike_one_pixel         (fc_in_computing ? fc_spike_data : spike_one_pixel),
        .spike_one_pixel_valid   (sparse_pixel_valid),
        .shift_spike_from_sparse (shift_spike_from_sparse),

        // config
        .input_channels          (input_channels),
        .pw_output_channels      (pw_output_channels),
        // .base_pw_weight_addr     (base_pw_weight_addr),
        // .base_pw_scale_addr      (base_pw_scale_addr),
        // .base_pw_bias_addr       (base_pw_bias_addr),
        // .base_pw_mp_addr         (base_pw_mp_addr),

        // SRAM port (global ren/wen fed back for the beat trackers)
        .sram_ren                (sram_ren),
        .sram_r_data             (sram_r_data),
        .sram_wen                (sram_wen),
        .sram_w_data             (sparse_sram_w_data),
        .sparse_spike_waddr      (sparse_spike_waddr),
        .sparse_spike_wen        (sparse_spike_wen),
        .sparse_spike_ren        (sparse_spike_ren),
        .fc_start                (fc_start),
        .fc_in_computing         (fc_in_computing),
        .acc_only_enable         (acc_only_enable),
        .fc_first_pixel_one_t    (fc_first_pixel_one_t),
        .class_label             (class_label),

        // dual-mode PE array
        .sparse_mp_clr           (sparse_mp_clr),
        .sparse_act              (sparse_act),
        .sparse_acc_en           (sparse_acc_en),
        .sparse_scale_en         (sparse_scale_en),
        .sparse_bias_en          (sparse_bias_en),
        .sparse_mp_en            (sparse_mp_en),
        .sparse_spike_en         (sparse_spike_en),
        .pooling_input           (pooling_input),
        .pooling_output          (pooling_output),
        .wb_mp_data              (pe_wb_mp_data),

        // connect to addr generator
        .pw_weight_en            (pw_weight_en),
        .pw_scale_en             (pw_scale_en),
        .combined_bias_rd_en     (combined_bias_rd_en),
        .combined_pw_mp_en                (combined_pw_mp_en),
        .pw_wb_mp_en             (pw_wb_mp_en),
        .fetch_s_addr            (fetch_s_addr),
        .fc_spike_vld            (fc_spike_vld),
        .fc_spike_data           (fc_spike_data),
        .shift_for_mem_bit_trans (shift_for_mem_bit_trans),
        .online_training_disable (online_training_disable),
        .updated_weight          (updated_weight),
        .pw_weight_wr_en         (pw_weight_wr_en)
    );

    DUAL_MODE_PE_ARRAY U_PE_ARRAY (
        .clk                (clk),
        .rst_n              (rst_n),

        .cmp_mode           (sparse_acc_en),
        .time_step          (fc_in_computing ? fc_time_step : time_step),

        // dense side
        .dense_spikes       (dense_spikes),
        .sram_r_data        (sram_r_data),
        .dense_inter_acc_en (dense_inter_acc_en),
        .dense_outer_acc_en (dense_outer_acc_en),
        .dense_scale_en     (dense_scale_en),
        .dense_bias_en      (dense_bias_en),
        .dense_mp_en        (dense_mp_en),
        .dense_spike_en     (dense_spike_en),

        // sparse side
        .final_cls_layer    (final_cls_layer),
        .sparse_mp_clr      (sparse_mp_clr),
        .sparse_act         (sparse_act),
        .fc_in_computing    (fc_in_computing),
        .sparse_acc_en      (sparse_acc_en),
        .sparse_scale_en    (sparse_scale_en),
        .sparse_bias_en     (sparse_bias_en),
        .sparse_mp_en       (sparse_mp_en),
        .sparse_spike_en    (sparse_spike_en),
        .pooling_input      (pooling_input),
        .pooling_output     (pooling_output),

        // results
        .spike_out          (pe_spike_out),
        .wb_mp_data         (pe_wb_mp_data),
        .gbl_start          (gbl_start),
        .online_training_disable (online_training_disable),
        .updated_weight          (updated_weight)
    );

    ADDR_GENERATOR U_ADDR_GEN (
        .clk                     (clk),

        .base_weight_addr        (base_weight_addr),
        .base_scale_addr         (base_scale_addr),
        .base_mp_addr            (base_mp_addr),
        .base_pw_weight_addr     (base_pw_weight_addr),
        .base_pw_scale_addr      (base_pw_scale_addr),
        .base_pw_mp_addr         (base_pw_mp_addr),

        // dense side
        .dense_spike_fetch_done  (fetch_spike_fetch_en),// dense_spike_fetch_done
        .dense_fetch_weight_en   (dense_fetch_weight_en),
        .dense_fetch_scale_en    (dense_fetch_scale_en),
        .dense_fetch_bias_en     (dense_fetch_bias_en),
        .dense_fetch_mp_en       (dense_fetch_mp_en),
        .dense_fetch_wb_mp_en    (dense_fetch_wb_mp_en),

        // sparse side (FC mode shares the same pixel-valid mux as sparse core)
        .spike_one_pixel_valid   (sparse_pixel_valid),
        .pw_weight_en            (pw_weight_en),
        .pw_scale_en             (pw_scale_en),
        .combined_pw_bias_en     (combined_bias_rd_en),
        .combined_pw_mp_en                (combined_pw_mp_en),
        .pw_wb_mp_en             (pw_wb_mp_en),

        // spike write-back / spike fetch (own address counters)
        .sparse_spike_waddr      (sparse_spike_waddr),
        .sparse_spike_wen        (sparse_spike_wen),
        .sparse_weight_wr_en     (pw_weight_wr_en),
        .fetch_spike_sram_r_addr (fetch_spike_sram_r_addr),
        .fetch_spike_sram_ren    (fetch_spike_sram_ren),

        .sram_ren                (ag_sram_ren),
        .sram_wen                (ag_sram_wen),
        .sram_r_addr             (ag_sram_r_addr),
        .sram_w_addr             (ag_sram_w_addr),
        .final_cls_layer         (final_cls_layer),
        .online_training_disable (online_training_disable)
    );

    // global SRAM port: addr generator covers dense/sparse, FC_CTRL reads on its own beats
    assign sram_ren    = ag_sram_ren | sram_ren_fc | sparse_spike_ren;
    assign sram_r_addr = sparse_spike_ren ? sparse_spike_waddr : ag_sram_ren ? ag_sram_r_addr : sram_r_addr_fc;

    assign sram_wen    = ag_sram_wen | fetch_spike_sram_wen;
    assign sram_w_addr = fetch_spike_sram_wen ? fetch_spike_sram_r_addr  : ag_sram_w_addr;
    assign sram_w_data = fetch_spike_sram_wen ? fetch_spike_sram_w_data : dense_fetch_wb_mp_en ? dense_sram_w_data : sparse_sram_w_data;

    
    always@(posedge clk or negedge rst_n) begin
        if(rst_n == 1'b0) begin
            shift_for_mem_bit_trans <= 0;
        end
        else begin
            shift_for_mem_bit_trans <= {shift_for_mem_bit_trans[RW_GAP_CYCLE-2:0], sram_ren | sram_wen | rd_inst_en};
        end
    end

    assign rw_ready = shift_for_mem_bit_trans[RW_GAP_CYCLE-1];

endmodule
