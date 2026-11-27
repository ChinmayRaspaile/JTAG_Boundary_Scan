`timescale 1ns/1ps
module boundary_scan_cell (
    input wire tck,
    input wire trst_n,

    input wire capture_dr,
    input wire shift_dr,
    input wire update_dr,

    input wire tdi,
    input wire pin_in,
    input wire system_out,

    input wire extest_enable,

    output wire tdo,
    output wire pin_out
);

    reg shift_reg;
    reg update_reg;

    // Capture, shift and reset logic
    always @(posedge tck or negedge trst_n) begin

        if (!trst_n) begin
            shift_reg <= 1'b0;
            update_reg <= 1'b0;
        end

        else if (capture_dr) begin
            shift_reg <= pin_in;
        end

        else if (shift_dr) begin
            shift_reg <= tdi;
        end

        else if (update_dr) begin
            update_reg <= shift_reg;
        end

    end

    // Serial output
    assign tdo = shift_reg;

    // Select functional or boundary scan output
    assign pin_out = extest_enable ? update_reg : system_out;

endmodule