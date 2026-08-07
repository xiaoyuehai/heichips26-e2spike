module NN_CTRL(
    input wire  clk,
    input wire  rst_n,

    input wire  gbl_start,
    output wire gbl_finish,

    // config: dense (depthwise) core
    output reg [8:0] base_weight_addr,
    // output reg [8:0] base_bias_addr,
    // output reg [8:0] base_pw_bias_addr,
    output reg [8:0] base_pw_scale_addr,
    output reg [8:0] base_scale_addr,
    output reg [8:0] base_pw_weight_addr,
    output wire [8:0] base_mp_addr,
    output wire [8:0] base_pw_mp_addr,

    output wire       row_has_two,
    output wire [7:0] mem_len_per_t,
    output reg [7:0] max_lenth,
    output reg [5:0] input_channels,
    output reg [5:0] pw_output_channels,
    output wire       final_cls_layer,
    output wire       ds_block_start,
    input wire       ds_block_end,
    output wire       fc_start,
    input wire       fc_finish,

    output reg [8:0] rd_inst_addr,
    output reg      rd_inst_en,
    input wire [31:0] rd_inst_data,
    input wire       rw_ready

);

    reg [3:0] layer_index;
    reg       in_process;
    reg       busy;
    wire      trigger_issue;
    reg [1:0]      rd_inst_flag;
    reg [63:0]     inst_data_reg;

    assign trigger_issue = in_process && ~busy;
    assign ds_block_start = rd_inst_flag == 1 && rw_ready && layer_index < 4'd3;
    assign fc_start = rd_inst_flag == 1 && rw_ready && layer_index > 4'd2;

    // parameters
    assign base_mp_addr = 496;
    assign base_pw_mp_addr = 504;
    wire [8:0] inst_addr_address = 278;

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            rd_inst_addr <= 0;
        end
        else if(gbl_start)begin
            rd_inst_addr <= inst_addr_address;
        end
        else if(rd_inst_en)begin
            rd_inst_addr <= rd_inst_addr + 1'b1;
        end
    end

    // assign rd_inst_en = trigger_issue || (rd_inst_flag == 0 && rw_ready);
    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            rd_inst_en <= 1'b0;
        end
        else if(trigger_issue)begin
            rd_inst_en <= 1'b1;
        end
        else if(rw_ready && rd_inst_flag == 0)begin
            rd_inst_en <= 1'b1;
        end
        else begin
            rd_inst_en <= 1'b0;
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            rd_inst_flag <= 0;
        end
        else if(trigger_issue)begin
            rd_inst_flag <= 0;
        end
        else if(rw_ready && rd_inst_flag != 2)begin
            rd_inst_flag <= rd_inst_flag + 1;
        end
    end

    always@(posedge clk)begin
        if(rw_ready && rd_inst_flag == 0)begin
            inst_data_reg[31:0] <= rd_inst_data;
        end
        if(rw_ready && rd_inst_flag == 1)begin
            inst_data_reg[63:32] <= rd_inst_data;
        end
    end

    // always@(posedge clk)begin
        
    // end
    always@(*)begin
        base_weight_addr = inst_data_reg[8:0];//yes
        // base_bias_addr = 164; 
        // base_pw_bias_addr = 172;
        base_pw_scale_addr = inst_data_reg[17:9];//yes
        base_scale_addr = inst_data_reg[26:18];//yes
        base_pw_weight_addr = inst_data_reg[35:27];//yes
        max_lenth = inst_data_reg[43:36];//yes
        input_channels = inst_data_reg[49:44];//yes
        pw_output_channels = inst_data_reg[55:50];//yes
    end
    // always@(*)begin
    //     case(layer_index)
    //         0:begin
    //             base_weight_addr = 160;//yes
    //             // base_bias_addr = 164; 
    //             // base_pw_bias_addr = 172;
    //             base_pw_scale_addr = 168;//yes
    //             base_scale_addr = 234;//yes
    //             base_pw_weight_addr = 234;//yes
    //             max_lenth = 80;//yes
    //             input_channels = 16;//yes
    //             pw_output_channels = 32;//yes
    //         end
    //         1:begin
    //             base_weight_addr = 180;
    //             // base_bias_addr = 188; 
    //             // base_pw_bias_addr = 200;
    //             base_pw_scale_addr = 196;
    //             base_scale_addr = 238;
    //             base_pw_weight_addr = 298;
    //             max_lenth = 40;
    //             input_channels = 32;
    //             pw_output_channels = 32;
    //         end
    //         2:begin
    //             base_weight_addr = 208;
    //             // base_bias_addr = 216; 
    //             // base_pw_bias_addr = 226;
    //             base_pw_scale_addr = 224;
    //             base_scale_addr = 246;
    //             base_pw_weight_addr = 426;
    //             max_lenth = 20;
    //             input_channels = 32;
    //             pw_output_channels = 16;
    //         end
    //         3:begin
    //             base_weight_addr = 180;//
    //             // base_bias_addr = 188; //
    //             // base_pw_bias_addr = 510;
    //             base_pw_scale_addr = 230;
    //             base_scale_addr = 236;//
    //             base_pw_weight_addr = 254;
    //             max_lenth = 40;
    //             input_channels = 16;
    //             pw_output_channels = 8;
    //         end
    //         4:begin
    //             base_weight_addr = 180;//
    //             // base_bias_addr = 188; //
    //             // base_pw_bias_addr = 510;
    //             base_pw_scale_addr = 232;
    //             base_scale_addr = 236;//
    //             base_pw_weight_addr = 270;
    //             max_lenth = 40;
    //             input_channels = 8;
    //             pw_output_channels = 8;
    //         end
    //         default:begin
    //             base_weight_addr = 0;
    //             base_bias_addr = 0;
    //             base_pw_bias_addr = 0;
    //             base_pw_scale_addr = 0;
    //             base_scale_addr = 0;
    //             base_pw_weight_addr = 0;
    //             max_lenth = 0;
    //             input_channels = 0;
    //             pw_output_channels = 0;
    //         end
    //     endcase
    // end
    assign row_has_two = layer_index == 0;
    assign mem_len_per_t = 40;
    assign final_cls_layer = layer_index == 4'd4;
    
    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            in_process <= 1'b0;
        end
        else if(gbl_start)begin
            in_process <= 1'b1;
        end
        else if(gbl_finish)begin
            in_process <= 1'b0;
        end
    end

    assign gbl_finish = layer_index == 4'd4 && fc_finish;
    
    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            busy <= 1'b0;
        end
        else if(trigger_issue)begin//ds_block_start || fc_start
            busy <= 1'b1;
        end
        else if(ds_block_end || fc_finish)begin
            busy <= 1'b0;
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            layer_index <= 4'd0;
        end
        else if(gbl_start)begin
            layer_index <= 4'd0;
        end
        else if(ds_block_end || fc_finish)begin
            if(layer_index == 4'd4)begin
                layer_index <= 4'd4;
            end
            else begin
                layer_index <= layer_index + 1'b1;
            end
        end
    end

endmodule