
`timescale 1ns/1ps

module board_interconnect_fault #(
    parameter WIDTH = 8
)(
    input wire [WIDTH-1:0] device_a_out,
    input wire [WIDTH-1:0] device_b_out,

    input wire fault_enable,
    input wire [2:0] fault_type,

    // 0: A-to-B, 1: B-to-A
    input wire fault_direction,

    // Bit positions used by the fault model
    input wire [3:0] fault_bit_a,
    input wire [3:0] fault_bit_b,

    output reg [WIDTH-1:0] device_a_in,
    output reg [WIDTH-1:0] device_b_in
);

    always @(*) begin

        // Normal interconnect
        device_b_in = device_a_out;
        device_a_in = device_b_out;

        if (fault_enable) begin

            case (fault_type)

                // Stuck-at-0
                3'd1: begin
                    if (fault_direction == 1'b0)
                        device_b_in[fault_bit_a] = 1'b0;
                    else
                        device_a_in[fault_bit_a] = 1'b0;
                end

                // Stuck-at-1
                3'd2: begin
                    if (fault_direction == 1'b0)
                        device_b_in[fault_bit_a] = 1'b1;
                    else
                        device_a_in[fault_bit_a] = 1'b1;
                end

                // Open circuit: high impedance
                3'd3: begin
                    if (fault_direction == 1'b0)
                        device_b_in[fault_bit_a] = 1'bz;
                    else
                        device_a_in[fault_bit_a] = 1'bz;
                end

                // Bridging fault: wired-AND model
                3'd4: begin
                    if (fault_direction == 1'b0) begin
                        device_b_in[fault_bit_a] =
                            device_a_out[fault_bit_a] &
                            device_a_out[fault_bit_b];

                        device_b_in[fault_bit_b] =
                            device_a_out[fault_bit_a] &
                            device_a_out[fault_bit_b];
                    end
                    else begin
                        device_a_in[fault_bit_a] =
                            device_b_out[fault_bit_a] &
                            device_b_out[fault_bit_b];

                        device_a_in[fault_bit_b] =
                            device_b_out[fault_bit_a] &
                            device_b_out[fault_bit_b];
                    end
                end

                default: begin
                    device_b_in = device_a_out;
                    device_a_in = device_b_out;
                end

            endcase
        end
    end

endmodule
