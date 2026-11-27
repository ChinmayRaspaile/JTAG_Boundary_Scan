`timescale 1ns/1ps

module tap_controller (
    input  wire tck,
    input  wire trst_n,
    input  wire tms,

    output reg  capture_dr,
    output reg  shift_dr,
    output reg  update_dr,

    output reg  capture_ir,
    output reg  shift_ir,
    output reg  update_ir,

    output reg  test_logic_reset,
    output reg  run_test_idle,

    output reg [3:0] current_state
);

    // IEEE 1149.1 TAP states
    localparam TEST_LOGIC_RESET = 4'd0;
    localparam RUN_TEST_IDLE    = 4'd1;
    localparam SELECT_DR_SCAN   = 4'd2;
    localparam CAPTURE_DR       = 4'd3;
    localparam SHIFT_DR         = 4'd4;
    localparam EXIT1_DR         = 4'd5;
    localparam PAUSE_DR         = 4'd6;
    localparam EXIT2_DR         = 4'd7;
    localparam UPDATE_DR        = 4'd8;
    localparam SELECT_IR_SCAN   = 4'd9;
    localparam CAPTURE_IR       = 4'd10;
    localparam SHIFT_IR         = 4'd11;
    localparam EXIT1_IR         = 4'd12;
    localparam PAUSE_IR         = 4'd13;
    localparam EXIT2_IR         = 4'd14;
    localparam UPDATE_IR        = 4'd15;

    // TAP state register
    always @(posedge tck or negedge trst_n) begin
        if (!trst_n)
            current_state <= TEST_LOGIC_RESET;
        else begin
            case (current_state)

                TEST_LOGIC_RESET:
                    current_state <= tms ? TEST_LOGIC_RESET : RUN_TEST_IDLE;

                RUN_TEST_IDLE:
                    current_state <= tms ? SELECT_DR_SCAN : RUN_TEST_IDLE;

                SELECT_DR_SCAN:
                    current_state <= tms ? SELECT_IR_SCAN : CAPTURE_DR;

                CAPTURE_DR:
                    current_state <= tms ? EXIT1_DR : SHIFT_DR;

                SHIFT_DR:
                    current_state <= tms ? EXIT1_DR : SHIFT_DR;

                EXIT1_DR:
                    current_state <= tms ? UPDATE_DR : PAUSE_DR;

                PAUSE_DR:
                    current_state <= tms ? EXIT2_DR : PAUSE_DR;

                EXIT2_DR:
                    current_state <= tms ? UPDATE_DR : SHIFT_DR;

                UPDATE_DR:
                    current_state <= tms ? SELECT_DR_SCAN : RUN_TEST_IDLE;

                SELECT_IR_SCAN:
                    current_state <= tms ? TEST_LOGIC_RESET : CAPTURE_IR;

                CAPTURE_IR:
                    current_state <= tms ? EXIT1_IR : SHIFT_IR;

                SHIFT_IR:
                    current_state <= tms ? EXIT1_IR : SHIFT_IR;

                EXIT1_IR:
                    current_state <= tms ? UPDATE_IR : PAUSE_IR;

                PAUSE_IR:
                    current_state <= tms ? EXIT2_IR : PAUSE_IR;

                EXIT2_IR:
                    current_state <= tms ? UPDATE_IR : SHIFT_IR;

                UPDATE_IR:
                    current_state <= tms ? SELECT_DR_SCAN : RUN_TEST_IDLE;

                default:
                    current_state <= TEST_LOGIC_RESET;

            endcase
        end
    end

    // Decode TAP state into control signals
    always @(*) begin

        capture_dr       = 1'b0;
        shift_dr         = 1'b0;
        update_dr        = 1'b0;

        capture_ir       = 1'b0;
        shift_ir         = 1'b0;
        update_ir        = 1'b0;

        test_logic_reset = 1'b0;
        run_test_idle    = 1'b0;

        case (current_state)

            TEST_LOGIC_RESET:
                test_logic_reset = 1'b1;

            RUN_TEST_IDLE:
                run_test_idle = 1'b1;

            CAPTURE_DR:
                capture_dr = 1'b1;

            SHIFT_DR:
                shift_dr = 1'b1;

            UPDATE_DR:
                update_dr = 1'b1;

            CAPTURE_IR:
                capture_ir = 1'b1;

            SHIFT_IR:
                shift_ir = 1'b1;

            UPDATE_IR:
                update_ir = 1'b1;

            default: begin
            end

        endcase
    end

endmodule
