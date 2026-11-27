
`timescale 1ns/1ps

module jtag_board_extest #(
    parameter BSR_WIDTH = 8,
    parameter [31:0] IDCODE_A = 32'h12345679,
    parameter [31:0] IDCODE_B = 32'h87654321
)(
    input wire tck,
    input wire trst_n,
    input wire tms,
    input wire tdi,

    input wire [BSR_WIDTH-1:0] system_out_a,
    input wire [BSR_WIDTH-1:0] system_out_b,

    output wire tdo,

    output wire [BSR_WIDTH-1:0] pin_out_a,
    output wire [BSR_WIDTH-1:0] pin_out_b,

    output wire [BSR_WIDTH-1:0] pin_in_a,
    output wire [BSR_WIDTH-1:0] pin_in_b,

    output wire [3:0] instruction_a,
    output wire [3:0] instruction_b,

    output wire [3:0] tap_state_a,
    output wire [3:0] tap_state_b
);

    // ------------------------------------------------
    // PCB INTERCONNECT
    // ------------------------------------------------

    board_interconnect #(
        .WIDTH(BSR_WIDTH)
    ) u_interconnect (
        .device_a_out(pin_out_a),
        .device_b_out(pin_out_b),

        .device_a_in(pin_in_a),
        .device_b_in(pin_in_b)
    );

    // ------------------------------------------------
    // TWO-DEVICE JTAG BOARD
    // ------------------------------------------------

    jtag_board #(
        .BSR_WIDTH(BSR_WIDTH),
        .IDCODE_A(IDCODE_A),
        .IDCODE_B(IDCODE_B)
    ) u_jtag_board (
        .tck(tck),
        .trst_n(trst_n),
        .tms(tms),
        .tdi(tdi),

        .pin_in_a(pin_in_a),
        .system_out_a(system_out_a),

        .pin_in_b(pin_in_b),
        .system_out_b(system_out_b),

        .tdo(tdo),

        .pin_out_a(pin_out_a),
        .pin_out_b(pin_out_b),

        .instruction_a(instruction_a),
        .instruction_b(instruction_b),

        .tap_state_a(tap_state_a),
        .tap_state_b(tap_state_b)
    );

endmodule
