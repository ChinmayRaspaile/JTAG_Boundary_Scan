`timescale 1ns/1ps
module bypass_register (
    input wire tck,
    input wire trst_n,
    input wire capture_dr,
    input wire shift_dr,
    input wire tdi,
    output wire tdo
);

    reg bypass_bit;

    assign tdo = bypass_bit;

    always @(posedge tck or negedge trst_n) begin

        if (!trst_n)
            bypass_bit <= 1'b0;

        else if (capture_dr)
            bypass_bit <= 1'b0;

        else if (shift_dr)
            bypass_bit <= tdi;

    end

endmodule

