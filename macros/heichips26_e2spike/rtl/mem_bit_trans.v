module MEM_BIT_TRANS (
    input  wire       clk,
    input  wire       rst_n,
    // read
    input  wire         sram_ren,
    input  wire [8:0]   sram_r_addr,
    input wire [15:0]   sram_r_data, //from sram
    input wire          sram_wen,
    input wire [8:0]    sram_w_addr,
    input wire [63:0]   sram_w_data, //to sram

    // out
    output wire [9:0]  o_addr,
    output wire       o_ren,
    output reg  [63:0]  o_rdata,
    output wire         o_wen,
    output reg [15:0]  o_wdata
);
    
    reg [3:0] rw_ff;
    reg rw_flag; //0: read, 1: write
    wire rw_en;
    reg [2:0] rw_cnt;

    assign rw_en = sram_ren | sram_wen | |rw_ff[2:0];

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            rw_flag <= 1'b0;
        end
        else if(sram_ren)begin
            rw_flag <= 1'b0;
        end
        else if(sram_wen)begin
            rw_flag <= 1'b1;
        end
    end

    always@(posedge clk or negedge rst_n) begin
        if(rst_n == 1'b0)begin
            rw_cnt <= 3'b000;
        end
        else if(rw_en)begin
            rw_cnt <= rw_cnt + 1'b1;
        end
        else begin
            rw_cnt <= 3'b000;
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            rw_ff <= 4'b0;
        end
        else begin
            rw_ff <= {rw_ff[2:0], sram_ren | sram_wen};
        end
    end

    assign o_addr = sram_ren ? {1'b0, sram_r_addr} : {1'b0, sram_w_addr};
    assign o_ren = sram_ren;
    assign o_wen = sram_wen;
    
    always@(posedge clk)begin
        if(|rw_ff && rw_flag == 1'b0)begin
            o_rdata <= {sram_r_data,o_rdata[63:16]};
        end
    end

    // write
    // assign o_wdata = sram_wen ? sram_w_data[7:0] : o_rdata[7:0];
    reg [47:0] wdata_reg;
    always@(posedge clk)begin
        if(sram_wen)begin
            wdata_reg <= sram_w_data[63:16];
        end
        else if(rw_cnt != 0)begin
            wdata_reg <= {16'b0, wdata_reg[47:16]};
        end
    end
    always@(*)begin
        o_wdata = sram_wen ? sram_w_data[15:0] : wdata_reg[15:0];
        // case(rw_cnt)
        //     3'b000: o_wdata = sram_w_data[7:0];
        //     3'b001: o_wdata = sram_w_data[15:8];
        //     3'b010: o_wdata = sram_w_data[23:16];
        //     3'b011: o_wdata = sram_w_data[31:24];
        //     3'b100: o_wdata = sram_w_data[39:32];
        //     3'b101: o_wdata = sram_w_data[47:40];
        //     3'b110: o_wdata = sram_w_data[55:48];
        //     3'b111: o_wdata = sram_w_data[63:56];
        //     default: o_wdata = 8'b0;
        // endcase
    end

endmodule