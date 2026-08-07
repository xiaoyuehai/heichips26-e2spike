module DUAL_MODE_PE (
    input wire                  clk,
    input wire                  rst_n,
    input wire                  cmp_mode,// 0: dense; 1: sparse;
    input wire [1:0]            time_step,
    //input act
    input wire [1:0]            act_0,
    input wire [1:0]            act_1,
    input wire [3:0]            in_w_0,
    input wire [3:0]            in_w_1,

    input wire signed [15:0]    neighbor_value,
    output wire signed [15:0]   to_neighbor_value,

    //computing logic
    input wire                  mp_clr,
    input wire                  inter_acc_en,
    input wire                  outer_acc_en,
    input wire                  scale_en,
    input wire  [7:0]           scale_value,
    input wire                  bias_en,
    input wire signed [15:0]    bias_value,
    input wire                  mp_en,
    input wire signed [15:0]    mp_value,
    input wire                  final_cls_layer,
    input wire                  spike_en,
    output reg [1:0]            spike_out,
    output reg signed [15:0]    wb_mp,
    input wire  [1:0]          pooling_input,
    output wire  [1:0]          pooling_output,
    output wire  [3:0]          updated_weight,
    input wire                  gbl_start,
    input wire                  online_training_disable
);
    localparam DENSE_MODE = 1'b0;
    localparam SPARSE_MODE = 1'b1;

    wire shift_dir = scale_value[7];
    wire [2:0] shift_amount = scale_value[2:0]; // range 0:6

    reg signed [15:0] res;
    reg signed [7:0] a,b;
    always@(*) begin
        case(act_0)
            2'b01: a = {{4{in_w_0[3]}},  in_w_0[3:0]};           // w*1
            2'b10: a = {{3{in_w_0[3]}},  in_w_0[3:0], 1'b0};     // w*2
            2'b11: a = {{2{in_w_0[3]}},  in_w_0[3:0], 2'b00};    // w*4
            default: a = 8'sd0;
        endcase
        case(act_1)
            2'b01: b = {{4{in_w_1[3]}},  in_w_1[3:0]};
            2'b10: b = {{3{in_w_1[3]}},  in_w_1[3:0], 1'b0};
            2'b11: b = {{2{in_w_1[3]}},  in_w_1[3:0], 2'b00};
            default: b = 8'sd0;
        endcase
    end
    reg signed [15:0] adder_a;
    reg signed [15:0] adder_b;
    wire signed [15:0] adder_res;

    always@(posedge clk) begin
        if(mp_clr == 1'b1)begin
            res <= 16'sd0;
        end
        // else if(inter_acc_en == 1'b1)begin
        //     res <= cmp_mode == DENSE_MODE ? b + a : res + a;//a + b
        // end
        // else if(outer_acc_en == 1'b1)begin
        //     res <= res + neighbor_value;
        // end
        else if(inter_acc_en || outer_acc_en || bias_en || mp_en) begin
            res <= adder_res;
        end
        else if(scale_en == 1'b1) begin
            if(shift_dir == 1'b0) res <= res <<< shift_amount;
            else                  res <= res >>> shift_amount;
        end
        // else if(bias_en == 1'b1) begin
        //     res <= res + bias_value;
        // end
        // else if(mp_en == 1'b1) begin
        //     if(final_cls_layer) res <= res + mp_value;
        //     else                res <= res + (mp_value >>> 1);
        //     // res <= res + (mp_value >>> 1);
        // end
    end

    always@(*) begin
        if(cmp_mode == DENSE_MODE && inter_acc_en == 1'b1) begin
            adder_a = b;
        end
        else begin
            adder_a = res;
        end
    end

    always@(*)begin
        case({inter_acc_en, outer_acc_en, bias_en, mp_en})
            4'b1000: adder_b = a;
            4'b0100: adder_b = neighbor_value;
            4'b0010: adder_b = bias_value;
            4'b0001: adder_b = final_cls_layer ? mp_value : (mp_value >>> 1);
            default: adder_b = 16'sd0;
        endcase
    end

    ADDER U_ADDER(
        .a(adder_a),
        .b(adder_b),
        .res(adder_res)
    );

    always@(posedge clk) begin
        if(spike_en) begin
            if      (res >= 16'sd48) spike_out <= 2'b11;   // signed compares
            else if (res >= 16'sd32) spike_out <= 2'b10;
            else if (res >= 16'sd16) spike_out <= 2'b01;
            else                     spike_out <= 2'b00;
        end
    end

    always@(*) begin
        if((spike_out != 2'b00 || &time_step) && ~final_cls_layer) begin
            wb_mp = 16'sd0;
        end
        else begin
            if (res > 16'sd127) wb_mp = 16'sd127;
            else if (res < -16'sd128) wb_mp = -16'sd128;
            else wb_mp = res;
        end
    end

    assign pooling_output = pooling_input <= spike_out ? spike_out : pooling_input;
    assign to_neighbor_value = res;

    reg spike_en_ff;
    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0) spike_en_ff <= 1'b0;
        else               spike_en_ff <= spike_en;
    end

    reg signed [15:0] v_learn;
    always@(posedge clk)begin
        if(spike_en) v_learn <= res;
    end

    // SDSP U_SDSP(
    //     .clk(clk),
    //     .rst_n(rst_n),
    //     .sample_start(gbl_start),
    //     .post_spike(spike_en_ff && (|spike_out) && final_cls_layer),
    //     .learn_en(~online_training_disable && final_cls_layer),
    //     .pre_spike(|act_0 && inter_acc_en),
    //     .mem_p(v_learn),
    //     .mem_w(in_w_0),
    //     .updated_weight(updated_weight)//,
    //     // .updated_weight_we(updated_weight_we)
    // );
    learning_top U_LEARNING_TOP(
        .clk(clk),
        .rst(~rst_n),
        .sample_start(gbl_start),
        .learn_en(~online_training_disable && final_cls_layer),
        .Vmem(v_learn),
        .spk_post(spike_en_ff && (|spike_out) && final_cls_layer),
        .spk_pre(|act_0 && inter_acc_en),
        .w(in_w_0),
        .w_next(updated_weight)
    );

endmodule

module ADDER#(
    parameter WIDTH = 16
)(
    input wire signed [WIDTH-1:0] a,
    input wire signed [WIDTH-1:0] b,
    output wire signed [WIDTH-1:0] res
);

    // always@(*) begin
    assign res = a + b;
    // end

endmodule



// module ADDER(
//     input wire signed []
// )