
`timescale 1ns/1ps

module jtag_board #(
    parameter BSR_WIDTH = 8,
    parameter [31:0] IDCODE_A = 32'h12345679,
    parameter [31:0] IDCODE_B = 32'h87654321
)(
    input wire tck,
    input wire trst_n,
    input wire tms,
    input wire tdi,

    input wire [BSR_WIDTH-1:0] pin_in_a,
    input wire [BSR_WIDTH-1:0] system_out_a,

    input wire [BSR_WIDTH-1:0] pin_in_b,
    input wire [BSR_WIDTH-1:0] system_out_b,

    output wire tdo,

    output wire [BSR_WIDTH-1:0] pin_out_a,
    output wire [BSR_WIDTH-1:0] pin_out_b,

    output wire [3:0] instruction_a,
    output wire [3:0] instruction_b,

    output wire [3:0] tap_state_a,
    output wire [3:0] tap_state_b
);

    // Internal serial connection
    wire tdi_b;
    wire tdo_a;
    wire tdo_b;

    // Device A
    jtag_top #(
        .BSR_WIDTH(BSR_WIDTH),
        .IDCODE_VALUE(IDCODE_A)
    ) device_a (
        .tck(tck),
        .trst_n(trst_n),
        .tms(tms),
        .tdi(tdi),
        .pin_in(pin_in_a),
        .system_out(system_out_a),
        .tdo(tdo_a),
        .pin_out(pin_out_a),
        .current_instruction(instruction_a),
        .tap_state(tap_state_a)
    );

    // Device B
    jtag_top #(
        .BSR_WIDTH(BSR_WIDTH),
        .IDCODE_VALUE(IDCODE_B)
    ) device_b (
        .tck(tck),
        .trst_n(trst_n),
        .tms(tms),
        .tdi(tdi_b),
        .pin_in(pin_in_b),
        .system_out(system_out_b),
        .tdo(tdo_b),
        .pin_out(pin_out_b),
        .current_instruction(instruction_b),
        .tap_state(tap_state_b)
    );

    // Daisy-chain connections
    assign tdi_b = tdo_a;
    assign tdo = tdo_b;

endmodule
