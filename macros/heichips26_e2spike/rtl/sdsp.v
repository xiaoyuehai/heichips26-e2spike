module SDSP #(
    parameter                       W_BITS   = 4,
    parameter                       CA_BITS  = 3,
    parameter                       P_BITS   = 16,
    // fixed thresholds (calibrate to your fixed-point; no host config)
    parameter signed [P_BITS-1:0]   V_TH     = 16'sd16,  // = firing threshold (res>=16 emits a spike)
    parameter        [CA_BITS-1:0]  CA_UP_LO = 3'd1,     // LTP allowed when CA_UP_LO <= ca < CA_UP_HI
    parameter        [CA_BITS-1:0]  CA_UP_HI = 3'd5,
    parameter        [CA_BITS-1:0]  CA_DN_LO = 3'd1,     // LTD allowed when CA_DN_LO <= ca < CA_DN_HI
    parameter        [CA_BITS-1:0]  CA_DN_HI = 3'd4
)(
    input  wire                     clk,
    input  wire                     rst_n,

    input  wire                     sample_start,   // reset Ca at start of each sample
    input  wire                     post_spike,     // post neuron fired this timestep -> Ca += 1
    input  wire                     learn_en,       // level enable: learning active for this layer
    input  wire                     pre_spike,      // presynaptic event this timestep (event-driven trigger)
    input  wire signed [P_BITS-1:0] mem_p,          // post membrane potential at decision
    input  wire        [W_BITS-1:0] mem_w,          // current weight

    output reg         [W_BITS-1:0] updated_weight,
    output reg                      updated_weight_we
);

    // 2's-complement signed weight: +7 / -8 for W_BITS=4
    localparam signed [W_BITS-1:0] W_MAX = {1'b0, {(W_BITS-1){1'b1}}};
    localparam signed [W_BITS-1:0] W_MIN = {1'b1, {(W_BITS-1){1'b0}}};

    // calcium: saturating count of post spikes over the current sample
    reg [CA_BITS-1:0] ca;
    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            ca <= {CA_BITS{1'b0}};
        end
        else if(sample_start)begin
            ca <= {CA_BITS{1'b0}};
        end
        else if(post_spike && ca != {CA_BITS{1'b1}})begin
            ca <= ca + 1'b1;
        end
    end

    // stop-learning windows + direction from V
    wire v_ge   = (mem_p >= V_TH);
    wire ca_up  = (ca >= CA_UP_LO) && (ca < CA_UP_HI);
    wire ca_dn  = (ca >= CA_DN_LO) && (ca < CA_DN_HI);

    wire do_ltp = learn_en & pre_spike &  v_ge & ca_up;
    wire do_ltd = learn_en & pre_spike & ~v_ge & ca_dn;

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            updated_weight    <= {W_BITS{1'b0}};
            updated_weight_we <= 1'b0;
        end
        else if(learn_en && pre_spike) begin
            if(do_ltp)      updated_weight <= ($signed(mem_w) == W_MAX) ? W_MAX : mem_w + 1'b1;
            else if(do_ltd) updated_weight <= ($signed(mem_w) == W_MIN) ? W_MIN : mem_w - 1'b1;
            else            updated_weight <= mem_w;
        end
    end

endmodule
