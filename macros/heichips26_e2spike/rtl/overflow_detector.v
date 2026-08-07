module overflow_detector (
    input  wire a,
    input  wire cin,
    input  wire carry,
    output wire y
);

    assign y = (cin && !a && carry) ||
               (!cin && a && !carry);

endmodule
