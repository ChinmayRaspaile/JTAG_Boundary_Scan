
`timescale 1ns/1ps

module board_interconnect #(
    parameter WIDTH = 8
)(
    input wire [WIDTH-1:0] device_a_out,
    input wire [WIDTH-1:0] device_b_out,

    output wire [WIDTH-1:0] device_a_in,
    output wire [WIDTH-1:0] device_b_in
);

    // PCB connections:
    // Device A output connects to Device B input
    assign device_b_in = device_a_out;

    // Device B output connects to Device A input
    assign device_a_in = device_b_out;

endmodule
