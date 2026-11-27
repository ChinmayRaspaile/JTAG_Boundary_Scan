
`timescale 1ns/1ps

module jtag_top #(
    parameter BSR_WIDTH = 8,
    parameter [31:0] IDCODE_VALUE = 32'h12345679
)(
    input wire tck,
    input wire trst_n,
    input wire tms,
    input wire tdi,

    input wire [BSR_WIDTH-1:0] pin_in,
    input wire [BSR_WIDTH-1:0] system_out,

    output wire tdo,
    output wire [BSR_WIDTH-1:0] pin_out,

    output wire [3:0] current_instruction,
    output wire [3:0] tap_state
);

    // JTAG instructions
    localparam EXTEST = 4'b0000;
    localparam SAMPLE = 4'b0001;
    localparam IDCODE = 4'b0010;
    localparam BYPASS = 4'b1111;

    // TAP controller signals
    wire capture_dr;
    wire shift_dr;
    wire update_dr;

    wire capture_ir;
    wire shift_ir;
    wire update_ir;

    wire test_logic_reset;
    wire run_test_idle;

    // Instruction register
    wire ir_tdo;

    // Data register outputs
    wire bypass_tdo;
    wire idcode_tdo;
    wire boundary_tdo;

    wire dr_tdo;

    // Register selection
    wire select_bypass;
    wire select_idcode;
    wire select_boundary;

    // Gated data register controls
    wire bypass_capture;
    wire bypass_shift;

    wire idcode_capture;
    wire idcode_shift;

    wire boundary_capture;
    wire boundary_shift;
    wire boundary_update;

    // EXTEST control
    wire extest_enable;

    // ------------------------------------------------
    // 1. TAP CONTROLLER
    // ------------------------------------------------

    tap_controller u_tap (
        .tck(tck),
        .trst_n(trst_n),
        .tms(tms),

        .capture_dr(capture_dr),
        .shift_dr(shift_dr),
        .update_dr(update_dr),

        .capture_ir(capture_ir),
        .shift_ir(shift_ir),
        .update_ir(update_ir),

        .test_logic_reset(test_logic_reset),
        .run_test_idle(run_test_idle),

        .current_state(tap_state)
    );

    // ------------------------------------------------
    // 2. INSTRUCTION REGISTER
    // ------------------------------------------------

    instruction_register u_ir (
        .tck(tck),
        .trst_n(trst_n),

        .capture_ir(capture_ir),
        .shift_ir(shift_ir),
        .update_ir(update_ir),

        .tdi(tdi),

        .tdo(ir_tdo),
        .current_instruction(current_instruction)
    );

    // ------------------------------------------------
    // 3. DATA REGISTER SELECTION MUX
    // ------------------------------------------------

    jtag_register_mux u_dr_mux (
        .instruction(current_instruction),

        .tdo_bypass(bypass_tdo),
        .tdo_idcode(idcode_tdo),
        .tdo_boundary(boundary_tdo),

        .selected_tdo(dr_tdo),

        .select_bypass(select_bypass),
        .select_idcode(select_idcode),
        .select_boundary(select_boundary)
    );

    // ------------------------------------------------
    // 4. GATE DATA REGISTER CONTROL SIGNALS
    // ------------------------------------------------

    assign bypass_capture = capture_dr & select_bypass;
    assign bypass_shift   = shift_dr   & select_bypass;

    assign idcode_capture = capture_dr & select_idcode;
    assign idcode_shift   = shift_dr   & select_idcode;

    assign boundary_capture = capture_dr & select_boundary;
    assign boundary_shift   = shift_dr   & select_boundary;
    assign boundary_update  = update_dr  & select_boundary;

    assign extest_enable = (current_instruction == EXTEST);

    // ------------------------------------------------
    // 5. BYPASS REGISTER
    // ------------------------------------------------

    bypass_register u_bypass (
        .tck(tck),
        .trst_n(trst_n),

        .capture_dr(bypass_capture),
        .shift_dr(bypass_shift),

        .tdi(tdi),
        .tdo(bypass_tdo)
    );

    // ------------------------------------------------
    // 6. IDCODE REGISTER
    // ------------------------------------------------

    idcode_register #(
        .IDCODE_VALUE(IDCODE_VALUE)
    ) u_idcode (
        .tck(tck),
        .trst_n(trst_n),

        .capture_dr(idcode_capture),
        .shift_dr(idcode_shift),

        .tdi(tdi),
        .tdo(idcode_tdo)
    );

    // ------------------------------------------------
    // 7. BOUNDARY SCAN REGISTER
    // ------------------------------------------------

    boundary_scan_register #(
        .WIDTH(BSR_WIDTH)
    ) u_bsr (
        .tck(tck),
        .trst_n(trst_n),

        .capture_dr(boundary_capture),
        .shift_dr(boundary_shift),
        .update_dr(boundary_update),

        .tdi(tdi),

        .pin_in(pin_in),
        .system_out(system_out),

        .extest_enable(extest_enable),

        .tdo(boundary_tdo),
        .pin_out(pin_out)
    );

    // ------------------------------------------------
    // 8. FINAL TDO MUX
    // ------------------------------------------------

    // During SHIFT_IR, output instruction-register data.
    // Otherwise, output the selected data-register data.

    assign tdo = shift_ir ? ir_tdo : dr_tdo;

endmodule
