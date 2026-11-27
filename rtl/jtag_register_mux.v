`timescale 1ns/1ps
module jtag_register_mux (
    input wire [3:0] instruction,

    input wire tdo_bypass,
    input wire tdo_idcode,
    input wire tdo_boundary,

    output reg selected_tdo,

    output reg select_bypass,
    output reg select_idcode,
    output reg select_boundary
);

    localparam EXTEST = 4'b0000;
    localparam SAMPLE = 4'b0001;
    localparam IDCODE = 4'b0010;
    localparam BYPASS = 4'b1111;

    always @(*) begin

        selected_tdo = tdo_bypass;

        select_bypass = 1'b1;
        select_idcode = 1'b0;
        select_boundary = 1'b0;

        case (instruction)

            EXTEST, SAMPLE: begin
                selected_tdo = tdo_boundary;

                select_bypass = 1'b0;
                select_idcode = 1'b0;
                select_boundary = 1'b1;
            end

            IDCODE: begin
                selected_tdo = tdo_idcode;

                select_bypass = 1'b0;
                select_idcode = 1'b1;
                select_boundary = 1'b0;
            end

            BYPASS: begin
                selected_tdo = tdo_bypass;

                select_bypass = 1'b1;
                select_idcode = 1'b0;
                select_boundary = 1'b0;
            end

            default: begin
                selected_tdo = tdo_bypass;

                select_bypass = 1'b1;
                select_idcode = 1'b0;
                select_boundary = 1'b0;
            end

        endcase

    end

endmodule
