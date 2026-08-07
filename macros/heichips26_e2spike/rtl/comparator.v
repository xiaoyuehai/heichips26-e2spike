module comparator (
    input  wire [2:0]  ca,
    input  wire [15:0] Vmem,
    output wire        up,
    output wire        down,
    input wire         spike_pre
);

    localparam [2:0]  THETA1 = 3'b001;
    localparam [2:0]  THETA2 = 3'b011;
    localparam [2:0]  THETA3 = 3'b110;
    localparam [15:0] THETAM = 16'b0000000000001001;

    assign up = spike_pre && (ca >= THETA1) &&
                (ca <  THETA3) &&
                (Vmem >= THETAM);

    assign down = spike_pre && (ca >= THETA1) &&
                  (ca <  THETA2) &&
                  (Vmem <  THETAM);

endmodule
