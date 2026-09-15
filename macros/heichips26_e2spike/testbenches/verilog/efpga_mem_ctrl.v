// SPDX-FileCopyrightText: 2026 The E2Spike team
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// eFPGA-side memory controller for heichips26_e2spike.
//
// The macro does not drive the SRAM directly. It emits one-cycle REN or WEN
// pulses with a 9-bit logical address and moves a 64-bit logical word as four
// 16-bit beats on the following four cycles. Something between the macro and
// the 1024 x 32 SRAM of the HeiChips eFPGA has to turn that into physical
// accesses. On the team's FPGA board this was rtl/fpga_emu/mem_ctrl.v around a
// Xilinx block RAM; on the chip it has to be implemented in the eFPGA fabric.
//
// This file is mem_ctrl.v line for line, with the block RAM replaced by the
// pins of the IHP SRAM primitive the fabric exposes (IHP_SRAM_1024x32_1RW in
// mole99/fabulous-tiles): per-bit mask A_BM instead of a 4-bit byte enable, and
// separate A_MEN / A_WEN / A_REN. The cycle behaviour is unchanged, so the
// testbench exercises the protocol the RTL was written against.
//
// Logical word a = {phys[a + 512], phys[a]}. Beat order on read and write:
// phys[a][15:0], phys[a][31:16], phys[a+512][15:0], phys[a+512][31:16].
//
// One deliberate difference to mem_ctrl.v: rw_flag and A_ADDR_reg get a reset.
// Without it the SRAM is read at address X on every cycle before the first
// access, and that X reaches the macro's ui_in. RTL simulation shrugs that
// off, gate-level simulation does not. An eFPGA implementation should reset
// them too; the macro's behaviour does not depend on the values.

`timescale 1ns / 1ps
`default_nettype none

module efpga_mem_ctrl (
    input  wire        clk,
    input  wire        rst_n,

    // macro side (uio_out[11:10], uio_out[9:0], uo_out, ui_in)
    input  wire        wen,
    input  wire        ren,
    input  wire [9:0]  addr,
    input  wire [15:0] din,
    output reg  [15:0] dout,

    // IHP SRAM side
    output wire        A_MEN,
    output wire        A_WEN,
    output wire        A_REN,
    output wire [9:0]  A_ADDR,
    output wire [31:0] A_DIN,
    output wire [31:0] A_BM,
    input  wire [31:0] A_DOUT
);

    reg [3:0] rw_cnt;
    reg       rw_in_progress;
    reg [9:0] A_ADDR_reg;
    reg       rw_flag;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)   rw_flag <= 1'b0;
        else if (wen) rw_flag <= 1'b1;
        else if (ren) rw_flag <= 1'b0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)          A_ADDR_reg <= 10'd0;
        else if (wen || ren) A_ADDR_reg <= addr;
    end

    wire rd_flag = (rw_flag == 1'b0 && rw_in_progress) || ren;
    wire wr_flag = (rw_flag == 1'b1 && rw_in_progress) || wen;

    wire [9:0] r_addr = ren ? addr : rw_cnt > 0 ? A_ADDR_reg + 10'd512 : A_ADDR_reg;
    wire [9:0] w_addr = wen ? addr : rw_cnt[1] ? A_ADDR_reg + 10'd512 : A_ADDR_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)            rw_in_progress <= 1'b0;
        else if (wen || ren)   rw_in_progress <= 1'b1;
        else if (rw_cnt == 3)  rw_in_progress <= 1'b0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rw_cnt <= 4'd0;
        end
        else if ((rd_flag && !ren) || wr_flag) begin
            if (rw_cnt == 3) rw_cnt <= 4'd0;
            else             rw_cnt <= rw_cnt + 4'd1;
        end
    end

    always @(*) begin
        case (rw_cnt[0:0])
            1'b0:    dout = A_DOUT[15:0];
            1'b1:    dout = A_DOUT[31:16];
            default: dout = 16'b0;
        endcase
    end

    reg [31:0] wr_data;
    reg [3:0]  wea;

    always @(*) begin
        if (wr_flag) begin
            case (rw_cnt[0:0])
                1'b0:    wr_data = {16'b0, din};
                1'b1:    wr_data = {din, 16'b0};
                default: wr_data = 32'b0;
            endcase
        end
        else begin
            wr_data = 32'b0;
        end
    end

    always @(*) begin
        if (wr_flag) begin
            case (rw_cnt[1:0])
                2'b00:   wea = 4'b0011;
                2'b01:   wea = 4'b1100;
                2'b10:   wea = 4'b0011;
                2'b11:   wea = 4'b1100;
                default: wea = 4'b0000;
            endcase
        end
        else begin
            wea = 4'b0000;
        end
    end

    // Block RAM with ena=1 reads on every cycle it does not write. The IHP
    // macro does the same with REN held high; on a write cycle it returns the
    // written word, which the macro never samples (MEM_BIT_TRANS only shifts
    // read data while its own rw_flag says read).
    assign A_MEN  = 1'b1;
    assign A_WEN  = |wea;
    assign A_REN  = 1'b1;
    assign A_ADDR = wr_flag ? w_addr : r_addr;
    assign A_DIN  = wr_data;
    assign A_BM   = {{8{wea[3]}}, {8{wea[2]}}, {8{wea[1]}}, {8{wea[0]}}};

endmodule

`default_nettype wire
