module DUAL_MODE_PE_ARRAY (
    input wire                  clk,
    input wire                  rst_n,

    input wire                  cmp_mode,// 0: dense; 1: sparse;
    input wire [1:0]            time_step,

    // input act for dense computing
    input wire [31:0]           dense_spikes,
    input wire [63:0]           sram_r_data,
    input wire                  dense_inter_acc_en,
    input wire                  dense_outer_acc_en,
    input wire                  dense_scale_en,
    input wire                  dense_bias_en,
    input wire                  dense_mp_en,
    input wire                  dense_spike_en,

    // input act for sparse computing
    input wire                  final_cls_layer,
    input wire                  sparse_mp_clr,
    input wire [1:0]            sparse_act,
    input wire                  fc_in_computing,
    input wire                  sparse_acc_en,
    input wire                  sparse_scale_en,
    input wire [1:0]            sparse_bias_en,
    input wire [1:0]            sparse_mp_en,
    input wire                  sparse_spike_en,
    input wire [15:0]           pooling_input,
    output wire [15:0]          pooling_output,

    // results (dense mode: only upper half, PE4..7, is valid)
    output wire [15:0]          spike_out,
    output wire [127:0]         wb_mp_data,
    input wire                  gbl_start,
    input wire                  online_training_disable,
    output wire [7:0]           updated_weight
);

    localparam DENSE_MODE  = 1'b0;
    localparam SPARSE_MODE = 1'b1;

    genvar i;
    wire signed [15:0] to_neighbor_value [0:7];
    wire [31:0] updated_weight_data;
    assign updated_weight = updated_weight_data[7:0];
    wire [31:0] sparse_weights = fc_in_computing ? sram_r_data[63:32] : sram_r_data[31:0];

    generate
        for(i=0;i<8;i=i+1)begin: PE_ARRAY
            DUAL_MODE_PE U_PE (
                .clk       (clk),
                .rst_n     (rst_n),
                .cmp_mode  (cmp_mode),
                .time_step (time_step),

                // channel c at dense_spikes[c*8 +: 8]; lower PE takes spikes 0/1, upper PE takes 2/3
                .act_0  (cmp_mode == DENSE_MODE ? dense_spikes[(i%4)*8 + (i/4)*4 +: 2] : sparse_act),
                .act_1  (dense_spikes[(i%4)*8 + (i/4)*4 + 2 +: 2]),
                // channel c weights at sram_r_data[c*16 +: 16]; lower PE takes w0/w1, upper PE takes w2/w3
                .in_w_0 (cmp_mode == DENSE_MODE ? sram_r_data[(i%4)*16 + (i/4)*8 +: 4] : sparse_weights[i*4 +: 4]),
                .in_w_1 (sram_r_data[(i%4)*16 + (i/4)*8 + 4 +: 4]),

                .neighbor_value    (i >= 4 ? to_neighbor_value[i-4] : 16'sd0),
                .to_neighbor_value (to_neighbor_value[i]),

                .mp_clr       (sparse_mp_clr),
                .inter_acc_en (dense_inter_acc_en || sparse_acc_en),
                .outer_acc_en (dense_outer_acc_en && cmp_mode == DENSE_MODE),
                .scale_en     (dense_scale_en || sparse_scale_en),
                .scale_value  (sram_r_data[i*8 +: 8]),
                .bias_en      (dense_bias_en || (i >= 4 ? sparse_bias_en[1] : sparse_bias_en[0])),
                .bias_value   (sram_r_data[(i%4)*16 +: 16]),
                .mp_en        (dense_mp_en || (i >= 4 ? sparse_mp_en[1] : sparse_mp_en[0])),
                .mp_value     (sram_r_data[(i%4)*16 +: 16]),
                .final_cls_layer (final_cls_layer),
                .spike_en     (dense_spike_en || sparse_spike_en),
                .spike_out    (spike_out[i*2 +: 2]),
                .wb_mp        (wb_mp_data[i*16 +: 16]),

                .pooling_input  (fc_in_computing ? 2'b00 : pooling_input[i*2 +: 2]),
                .pooling_output (pooling_output[i*2 +: 2]),
                .updated_weight (updated_weight_data[i*4 +: 4]),
                .gbl_start      (gbl_start),
                .online_training_disable (online_training_disable)
            );
        end
    endgenerate

endmodule
