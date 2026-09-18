// SPDX-FileCopyrightText: 2026 The E2Spike team
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Self-checking testbench for heichips26_e2spike at its pins.
//
// The DUT is the RTL (rtl/*.v) or, compiled with -DGL, the committed netlist
// final/nl/heichips26_e2spike.nl.v. Around it sits what the HeiChips chip puts
// there: the eFPGA memory controller (efpga_mem_ctrl.v) and the IHP 1024x32
// SRAM model from the PDK. Nothing inside the DUT is forced.
//
// Run it with `make sim-rtl-verilog` or `make sim-gl-verilog` from the macro
// directory. The default run loads interface/bank_cfg.pat (sample 0 of the
// chb01 EEG set), runs one inference and checks
//   * the SRAM contents after ds1, ds2, ds3 and fc1 and at the end, word for
//     word, against expected/sample0_*.hex
//   * the class label and the number of clock cycles
//   * the SRAM protocol: no REN and WEN together, no access within the four
//     beats of the previous one, address bit 9 low, no X on the control pins,
//     the address or the write data
// The reference snapshots come from an RTL run whose every layer matched the
// bit-accurate golden model; the committed netlist reproduces them exactly.
//
// Plusargs
//   +MEMFILE=<pat>        image for the first inference (default ../../interface/bank_cfg.pat)
//   +MEMFILE<k>=<pat>     image for inference k >= 1; the fc2 weight words are
//                         kept, so on-chip learning carries over
//   +NINFER=<n>           number of inferences (default 1)
//   +RESET_BETWEEN        pulse rst_n before every inference after the first.
//                         Required: without it the second inference ends 142
//                         cycles early with some spikes wrong in every layer
//                         (hidden when the same image runs twice), see the macro
//                         README, known issue 1
//   +TRAIN_DISABLE=<0|1>  uio_in[1] (default 1, learning off)
//   +EXPECT_DIR=<dir>     compare snapshots of inference 0 against <dir>/sample0_*.hex
//   +EXPECT_CLASS=<0|1>   expected class_label of inference 0
//   +EXPECT_CYCLES=<n>    expected cycles from gbl_start to gbl_finish of inference 0
//   +OUTDIR=<dir>         where snapshots and traces are written (default sim_build)
//   +TIMEOUT=<cycles>     per inference (default 3000000)
//   +WAVES                dump pins, controller and SRAM port to <OUTDIR>/heichips26_e2spike_tb.fst
//
// The last line is "TB PASS: ..." or "TB FAIL: ...".

`timescale 1ns / 1ps
`default_nettype none

`ifdef GL
`define LAYER_INDEX {dut.\U_MICRO_BRAIN_TOP.U_NN_CTRL.layer_index[3] , \
                     dut.\U_MICRO_BRAIN_TOP.U_NN_CTRL.layer_index[2] , \
                     dut.\U_MICRO_BRAIN_TOP.U_NN_CTRL.layer_index[1] , \
                     dut.\U_MICRO_BRAIN_TOP.U_NN_CTRL.layer_index[0] }
`else
`define LAYER_INDEX dut.U_MICRO_BRAIN_TOP.U_NN_CTRL.layer_index
`endif

`define SRAM_MEM sram.i_SRAM_1P_behavioral_bm_bist.memory

module heichips26_e2spike_tb;

    localparam CLK_PERIOD = 10;

    reg clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    reg rst_n         = 1'b0;
    reg gbl_start     = 1'b0;
    reg train_disable = 1'b1;

    wire [15:0] ui_in;
    wire [15:0] uo_out;
    wire [15:0] uio_in = {14'b0, train_disable, gbl_start};
    wire [15:0] uio_out;
    wire [15:0] uio_oe;

    heichips26_e2spike dut (
        .ui_in   (ui_in),
        .uo_out  (uo_out),
        .uio_in  (uio_in),
        .uio_out (uio_out),
        .uio_oe  (uio_oe),
        .ena     (1'b1),
        .clk     (clk),
        .rst_n   (rst_n)
    );

    wire [9:0] sram_addr   = uio_out[9:0];
    wire       sram_ren    = uio_out[10];
    wire       sram_wen    = uio_out[11];
    wire       gbl_finish  = uio_out[12];
    wire       class_label = uio_out[13];

    wire        A_MEN, A_WEN, A_REN;
    wire [9:0]  A_ADDR;
    wire [31:0] A_DIN, A_BM, A_DOUT;

    efpga_mem_ctrl mem_ctrl (
        .clk    (clk),
        .rst_n  (rst_n),
        .wen    (sram_wen),
        .ren    (sram_ren),
        .addr   (sram_addr),
        .din    (uo_out),
        .dout   (ui_in),
        .A_MEN  (A_MEN),
        .A_WEN  (A_WEN),
        .A_REN  (A_REN),
        .A_ADDR (A_ADDR),
        .A_DIN  (A_DIN),
        .A_BM   (A_BM),
        .A_DOUT (A_DOUT)
    );

    RM_IHPSG13_1P_1024x32_c2_bm_bist sram (
        .A_CLK       (clk),
        .A_MEN       (A_MEN),
        .A_WEN       (A_WEN),
        .A_REN       (A_REN),
        .A_ADDR      (A_ADDR),
        .A_DIN       (A_DIN),
        .A_DLY       (1'b1),
        .A_DOUT      (A_DOUT),
        .A_BM        (A_BM),
        .A_BIST_CLK  (1'b0),
        .A_BIST_EN   (1'b0),
        .A_BIST_MEN  (1'b0),
        .A_BIST_WEN  (1'b0),
        .A_BIST_REN  (1'b0),
        .A_BIST_ADDR (10'b0),
        .A_BIST_DIN  (32'b0),
        .A_BIST_BM   (32'b0)
    );

    // ------------------------------------------------------------------
    // options and bookkeeping
    // ------------------------------------------------------------------
    reg [8*512-1:0] outdir;
    reg [8*512-1:0] expect_dir;
    reg [8*512-1:0] memfile;
    reg [8*64-1:0]  key;
    reg [8*600-1:0] fname;
    integer ninfer, timeout, train_arg, expect_class, expect_cycles;
    reg     have_expect_dir;

    integer cycle = 0;
    integer infer = 0;
    integer trace_fd = 0;
    integer proto_errors = 0;
    integer x_errors = 0;
    integer failures = 0;
    integer last_op_cycle = -100;
    reg     running = 1'b0;

    always @(posedge clk) cycle <= cycle + 1;

    task automatic fail(input [8*120-1:0] msg);
        begin
            failures = failures + 1;
            $display("CHECK FAIL infer=%0d cycle=%0d %0s", infer, cycle, msg);
        end
    endtask

    task automatic report_proto(input [8*96-1:0] msg);
        begin
            proto_errors = proto_errors + 1;
            if (proto_errors <= 20)
                $display("PROTO infer=%0d cycle=%0d %0s", infer, cycle, msg);
        end
    endtask

    // ------------------------------------------------------------------
    // protocol checks and access trace
    // ------------------------------------------------------------------
    reg [63:0] wdata_acc;
    integer    wbeat = -1;
    reg [8:0]  waddr_acc;

    always @(posedge clk) begin
        if (rst_n && running) begin
            if (^{sram_ren, sram_wen, gbl_finish} === 1'bx) begin
                x_errors = x_errors + 1;
                if (x_errors <= 20)
                    $display("XCHK infer=%0d cycle=%0d ren/wen/finish is X", infer, cycle);
            end
            if (sram_ren === 1'b1 && sram_wen === 1'b1)
                report_proto("REN and WEN in the same cycle");
            if (sram_ren === 1'b1 || sram_wen === 1'b1) begin
                if (^sram_addr === 1'bx) begin
                    x_errors = x_errors + 1;
                    if (x_errors <= 20)
                        $display("XCHK infer=%0d cycle=%0d address is X on an access", infer, cycle);
                end
                if (sram_addr[9] !== 1'b0)
                    report_proto("address bit 9 set, the logical space is 0..511");
                if (cycle - last_op_cycle < 5)
                    report_proto("access starts inside the previous 4-beat transfer");
                last_op_cycle = cycle;
                if (sram_ren === 1'b1 && trace_fd != 0)
                    $fdisplay(trace_fd, "%0d R %0d", cycle, sram_addr[8:0]);
                if (sram_wen === 1'b1) begin
                    wbeat     = 0;
                    waddr_acc = sram_addr[8:0];
                end
            end
            if (wbeat >= 0) begin
                if (^uo_out === 1'bx) begin
                    x_errors = x_errors + 1;
                    if (x_errors <= 20)
                        $display("XCHK infer=%0d cycle=%0d write data beat %0d is X", infer, cycle, wbeat);
                end
                wdata_acc[wbeat*16 +: 16] = uo_out;
                wbeat = wbeat + 1;
                if (wbeat == 4) begin
                    if (trace_fd != 0)
                        $fdisplay(trace_fd, "%0d W %0d %016h", cycle - 3, waddr_acc, wdata_acc);
                    wbeat = -1;
                end
            end
        end
    end

    // ------------------------------------------------------------------
    // snapshots after every layer, compared for inference 0
    // ------------------------------------------------------------------
    reg [31:0] expbuf [0:1023];
    integer    k, bad, first_bad;

    task automatic snapshot(input [8*16-1:0] name);
        begin
            $sformat(fname, "%0s/snap%0d_%0s.hex", outdir, infer, name);
            $writememh(fname, `SRAM_MEM);
            if (infer == 0 && have_expect_dir) begin
                for (k = 0; k < 1024; k = k + 1) expbuf[k] = 32'hxxxxxxxx;
                $sformat(fname, "%0s/sample0_%0s.hex", expect_dir, name);
                $readmemh(fname, expbuf);
                bad = 0;
                first_bad = -1;
                for (k = 0; k < 1024; k = k + 1) begin
                    if (`SRAM_MEM[k] !== expbuf[k]) begin
                        bad = bad + 1;
                        if (first_bad < 0) first_bad = k;
                    end
                end
                if (bad == 0) begin
                    $display("SNAP infer=0 %0s: all 1024 SRAM words match %0s", name, fname);
                end
                else begin
                    $display("SNAP infer=0 %0s: %0d words differ from %0s, first at physical %0d (got %08h, expected %08h)",
                             name, bad, fname, first_bad, `SRAM_MEM[first_bad], expbuf[first_bad]);
                    failures = failures + 1;
                end
            end
        end
    endtask

    reg [3:0] layer_prev;

    always @(posedge clk) begin
        if (rst_n && running) begin
            if (`LAYER_INDEX !== layer_prev) begin
                if (^layer_prev !== 1'bx) begin
                    case (layer_prev)
                        4'd0: snapshot("after_ds1");
                        4'd1: snapshot("after_ds2");
                        4'd2: snapshot("after_ds3");
                        4'd3: snapshot("after_fc1");
                        default: ;
                    endcase
                end
                $display("LAYER infer=%0d layer=%0d cycle=%0d", infer, `LAYER_INDEX, cycle);
                layer_prev <= `LAYER_INDEX;
            end
        end
    end

    // ------------------------------------------------------------------
    // image loading
    // ------------------------------------------------------------------
    reg [31:0] loadbuf [0:1023];
    reg [31:0] keep [0:7];
    integer    i;

    task automatic load_image(input integer n);
        begin
            if (n == 0) begin
                if (!$value$plusargs("MEMFILE=%s", memfile)) memfile = "../../interface/bank_cfg.pat";
            end
            else begin
                $sformat(key, "MEMFILE%0d=%%s", n);
                if (!$value$plusargs(key, memfile)) memfile = "../../interface/bank_cfg.pat";
            end
            for (i = 0; i < 1024; i = i + 1) loadbuf[i] = 32'hxxxxxxxx;
            $readmemh(memfile, loadbuf);
            for (i = 0; i < 1024; i = i + 1) begin
                if (^loadbuf[i] === 1'bx) begin
                    $display("TB FAIL: %0s has fewer than 1024 words", memfile);
                    $finish;
                end
            end
            // fc2 weights, high half of logical 270..277 = physical 782..789,
            // are the only words on-chip learning writes; they carry over
            if (n > 0)
                for (i = 0; i < 8; i = i + 1) keep[i] = `SRAM_MEM[782 + i];
            for (i = 0; i < 1024; i = i + 1) `SRAM_MEM[i] = loadbuf[i];
            if (n > 0)
                for (i = 0; i < 8; i = i + 1) `SRAM_MEM[782 + i] = keep[i];
            $display("LOAD infer=%0d %0s", n, memfile);
        end
    endtask

    // ------------------------------------------------------------------
    // main sequence
    // ------------------------------------------------------------------
    integer start_cycle;
    integer last_cycles = 0;
    reg     class_at_finish;

    initial begin
        if (!$value$plusargs("OUTDIR=%s", outdir))              outdir = "sim_build";
        have_expect_dir = $value$plusargs("EXPECT_DIR=%s", expect_dir);
        if (!$value$plusargs("NINFER=%d", ninfer))              ninfer = 1;
        if (!$value$plusargs("TIMEOUT=%d", timeout))            timeout = 3000000;
        if (!$value$plusargs("TRAIN_DISABLE=%d", train_arg))    train_arg = 1;
        if (!$value$plusargs("EXPECT_CLASS=%d", expect_class))  expect_class = -1;
        if (!$value$plusargs("EXPECT_CYCLES=%d", expect_cycles)) expect_cycles = -1;
        train_disable = train_arg[0];

        if ($test$plusargs("WAVES")) begin
            $sformat(fname, "%0s/heichips26_e2spike_tb.fst", outdir);
            $dumpfile(fname);
            $dumpvars(1, heichips26_e2spike_tb);
            $dumpvars(1, heichips26_e2spike_tb.mem_ctrl);
        end

        layer_prev = 4'bxxxx;
        repeat (5) @(posedge clk);
        #1 rst_n = 1'b1;
        repeat (5) @(posedge clk);

        for (infer = 0; infer < ninfer; infer = infer + 1) begin
            if (infer > 0 && $test$plusargs("RESET_BETWEEN")) begin
                #1 rst_n = 1'b0;
                repeat (5) @(posedge clk);
                #1 rst_n = 1'b1;
                repeat (5) @(posedge clk);
            end
            load_image(infer);
            $sformat(fname, "%0s/trace%0d.txt", outdir, infer);
            trace_fd = $fopen(fname, "w");
            proto_errors = 0;
            x_errors = 0;
            layer_prev = 4'bxxxx;

            @(posedge clk);
            #1 gbl_start = 1'b1;
            running = 1'b1;
            @(posedge clk);
            #1 gbl_start = 1'b0;
            start_cycle = cycle;

            while (gbl_finish !== 1'b1 && cycle - start_cycle < timeout)
                @(posedge clk);

            if (gbl_finish !== 1'b1) begin
                $display("RESULT infer=%0d class=timeout cycles=%0d", infer, cycle - start_cycle);
                $display("TB FAIL: gbl_finish did not come within %0d cycles", timeout);
                $fclose(trace_fd);
                $finish;
            end

            class_at_finish = class_label;
            last_cycles = cycle - start_cycle;
            repeat (6) @(posedge clk);
            running = 1'b0;
            snapshot("final");
            $fclose(trace_fd);
            trace_fd = 0;
            if (class_label !== class_at_finish)
                report_proto("class_label changed after gbl_finish");
            $display("RESULT infer=%0d class=%0b cycles=%0d proto_errors=%0d x_errors=%0d",
                     infer, class_at_finish, last_cycles, proto_errors, x_errors);
            if (proto_errors) fail("SRAM protocol violations");
            if (x_errors) fail("X on control, address or write data");
            if (infer == 0 && expect_class >= 0 && class_at_finish !== expect_class[0])
                fail("class_label differs from +EXPECT_CLASS");
            if (infer == 0 && expect_cycles >= 0 && last_cycles != expect_cycles)
                fail("cycle count differs from +EXPECT_CYCLES");
            repeat (10) @(posedge clk);
        end

        if (failures == 0)
            $display("TB PASS: %0d inference(s), last class %0b after %0d cycles, all checks passed",
                     ninfer, class_at_finish, last_cycles);
        else
            $display("TB FAIL: %0d check(s) failed, see the CHECK FAIL and SNAP lines above", failures);
        $finish;
    end

endmodule

`default_nettype wire
