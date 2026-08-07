module ca_counter (
    input  wire       clk,
    input  wire       rst,
    input  wire       sample_start,
    input  wire       spk_post,
    input  wire       leak_event,
    output wire [2:0] ca
);

    localparam [2:0] CA_MIN = 3'b000;
    localparam [2:0] CA_MAX = 3'b111;

    reg [2:0] ca_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ca_reg <= CA_MIN;
        end else if (sample_start) begin
            ca_reg <= CA_MIN;
        end else begin
            case ({spk_post, leak_event})
                2'b10: begin
                    if (ca_reg < CA_MAX)
                        ca_reg <= ca_reg + 3'b001;
                end

                2'b01: begin
                    if (ca_reg > CA_MIN)
                        ca_reg <= ca_reg - 3'b001;
                end

                default: begin
                    ca_reg <= ca_reg;
                end
            endcase
        end
    end

    assign ca = ca_reg;

endmodule
