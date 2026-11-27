`timescale 1ns/1ps

module idcode_register #(
    parameter [31:0] IDCODE_VALUE = 32'h12345679
)(
    input wire tck,
    input wire trst_n,

    input wire capture_dr,
    input wire shift_dr,

    input wire tdi,

    output wire tdo
);

    reg [31:0] shift_reg;

    assign tdo = shift_reg[0];

    always @(posedge tck or negedge trst_n) begin

        if (!trst_n)
            shift_reg <= IDCODE_VALUE;

        else if (capture_dr)
            shift_reg <= IDCODE_VALUE;

        else if (shift_dr)
            shift_reg <= {tdi, shift_reg[31:1]};

    end

endmodule
