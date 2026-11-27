`timescale 1ns/1ps

module instruction_register (
    input wire tck,
    input wire trst_n,

    input wire capture_ir,
    input wire shift_ir,
    input wire update_ir,

    input wire tdi,

    output wire tdo,
    output reg [3:0] current_instruction
);

    // Instruction encodings
    localparam EXTEST  = 4'b0000;
    localparam SAMPLE  = 4'b0001;
    localparam IDCODE  = 4'b0010;
    localparam BYPASS  = 4'b1111;

    reg [3:0] shift_reg;

    // Serial output is the least significant bit
    assign tdo = shift_reg[0];

    // IR shift and capture register
    always @(posedge tck or negedge trst_n) begin

        if (!trst_n)
            shift_reg <= 4'b0001;

        else if (capture_ir)
            shift_reg <= 4'b0001;

        else if (shift_ir)
            shift_reg <= {tdi, shift_reg[3:1]};

    end

    // Instruction update register
    always @(posedge tck or negedge trst_n) begin

        if (!trst_n)
            current_instruction <= IDCODE;

        else if (update_ir)
            current_instruction <= shift_reg;

    end

endmodule
