`timescale 1ns/1ps
module boundary_scan_register #(
    parameter WIDTH = 8
)(
    input wire tck,
    input wire trst_n,

    input wire capture_dr,
    input wire shift_dr,
    input wire update_dr,

    input wire tdi,

    input wire [WIDTH-1:0] pin_in,
    input wire [WIDTH-1:0] system_out,

    input wire extest_enable,

    output wire tdo,
    output wire [WIDTH-1:0] pin_out
);

    wire [WIDTH:0] serial_chain;

    assign serial_chain[0] = tdi;
    assign tdo = serial_chain[WIDTH];

    genvar i;

    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : BSR_CELLS

            boundary_scan_cell u_cell (
                .tck(tck),
                .trst_n(trst_n),

                .capture_dr(capture_dr),
                .shift_dr(shift_dr),
                .update_dr(update_dr),

                .tdi(serial_chain[i]),
                .pin_in(pin_in[i]),
                .system_out(system_out[i]),

                .extest_enable(extest_enable),

                .tdo(serial_chain[i+1]),
                .pin_out(pin_out[i])
            );

        end
    endgenerate

endmodule