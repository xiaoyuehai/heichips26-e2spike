module mem_ctrl(
    input wire clk,
    input wire rst_n,

    input wire wen,
    input wire ren,
    input wire [9:0] addr,
    input wire [15:0] din,
    output reg [15:0] dout

);
    // reg [31:0] banka_mem [0:1023];
    wire [31:0] A_DOUT_internal;
    reg [3:0] rw_cnt;
    reg rw_in_progress;

    reg [9:0] A_ADDR_reg;
    reg rw_flag;

    always@(posedge clk)begin
        if(wen)begin
            rw_flag <= 1;
        end
        else if(ren)begin
            rw_flag <= 0;
        end
    end

    always@(posedge clk)begin
        if(wen || ren)begin
            A_ADDR_reg <= addr;
        end
    end

    wire rd_flag = (rw_flag == 0 && rw_in_progress) || ren;
    wire wr_flag = (rw_flag == 1 && rw_in_progress) || wen;

    // wire [9:0] r_addr = A_REN || A_WEN ? A_ADDR : ~rw_cnt[2] ? A_ADDR_reg : A_ADDR_reg + 512;
    wire [9:0] r_addr = ren ? addr : rw_cnt > 0 ? A_ADDR_reg + 512 : A_ADDR_reg;
    wire [9:0] w_addr = wen ? addr : rw_cnt[1] ? A_ADDR_reg + 512 : A_ADDR_reg;


    // wire [31:0] pre_data = banka_mem[w_addr];


    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            rw_in_progress <= 1'b0;
        end
        else if(wen || ren)begin
            rw_in_progress <= 1'b1;
        end
        else if(rw_cnt == 3) begin
            rw_in_progress <= 1'b0;
        end
    end
    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            rw_cnt <= 0;
        end
        // if(A_WEN || A_REN)begin
        //     rw_cnt <= 0;
        // end
        else if((rd_flag && !ren) || wr_flag)begin
            if(rw_cnt == 3)begin
                rw_cnt <= 0;
            end
            else begin
                rw_cnt <= rw_cnt + 1'b1;
            end
        end
    end
    // write
    // always@(posedge A_CLK) begin
    //     // if(A_MEN && A_WEN) begin
    //     //     banka_mem[A_ADDR] <= A_DIN;
    //     // end
    //     if(wr_flag) begin
    //         case(rw_cnt[0:0])
    //             1'b0: banka_mem[w_addr] <= {pre_data[31:16], A_DIN[15:0]};
    //             1'b1: banka_mem[w_addr] <= {A_DIN[15:0], pre_data[15:0]};
    //             default: banka_mem[w_addr] <= pre_data;
    //         endcase
    //     end
    // end

    // read
    // always@(posedge A_CLK) begin
    //     if(rd_flag) begin
    //         A_DOUT_internal <= banka_mem[r_addr];
    //     end
    // end

    always@(*)begin
        case(rw_cnt[0:0])
            1'b0: dout = A_DOUT_internal[15:0];
            1'b1: dout = A_DOUT_internal[31:16];
            default: dout = 16'b0;
        endcase
    end
    reg [31:0] wr_data;
    reg [3:0] wea;

    always@(*)begin
        if(wr_flag)begin
            case(rw_cnt[0:0])
                1'b0: wr_data = {16'b0, din};
                1'b1: wr_data = {din, 16'b0};
                default: wr_data = 32'b0;
            endcase
        end
        else begin
            wr_data = 32'b0;
        end
    end

    always@(*)begin
        if(wr_flag)begin
            case(rw_cnt[1:0])
                2'b00: wea = 4'b0011;
                2'b01: wea = 4'b1100;
                2'b10: wea = 4'b0011;
                2'b11: wea = 4'b1100;
                default: wea = 4'b0000;
            endcase
        end
        else begin
            wea = 4'b0000;
        end
    end

    HEICHIPS_SRAM U_HEICHIPS_SRAM (
        .clka(clk),    // input wire clka
        .ena(1),      // input wire ena
        .wea(wea),      // input wire [3 : 0] wea
        .addra(wr_flag ? w_addr : r_addr),  // input wire [9 : 0] addra
        .dina(wr_data),    // input wire [31 : 0] dina
        .douta(A_DOUT_internal)  // output wire [31 : 0] douta
        );

endmodule