`timescale 1ns/1ps

module tb_jtag_top;

    localparam [31:0] IDCODE_VALUE = 32'h12345679;

    reg tck;
    reg trst_n;
    reg tms;
    reg tdi;

    reg [7:0] pin_in;
    reg [7:0] system_out;

    wire tdo;
    wire [7:0] pin_out;

    wire [3:0] current_instruction;
    wire [3:0] tap_state;

    integer passed;
    integer failed;
    integer i;

    reg sampled_tdo;
    reg [31:0] received_data;
    reg [31:0] expected_data;

    jtag_top #(
        .BSR_WIDTH(8),
        .IDCODE_VALUE(IDCODE_VALUE)
    ) uut (
        .tck(tck),
        .trst_n(trst_n),
        .tms(tms),
        .tdi(tdi),

        .pin_in(pin_in),
        .system_out(system_out),

        .tdo(tdo),
        .pin_out(pin_out),

        .current_instruction(current_instruction),
        .tap_state(tap_state)
    );

    // 10 ns clock period
    always #5 tck = ~tck;

    // ------------------------------------------------
    // CHECK TASK
    // ------------------------------------------------

    task check;
        input condition;
        input [200*8:1] message;

        begin
            if (condition) begin
                $display("[PASS] %0s", message);
                passed = passed + 1;
            end
            else begin
                $display("[FAIL] %0s", message);
                failed = failed + 1;
            end
        end
    endtask

    // ------------------------------------------------
    // JTAG CLOCK STEP
    // ------------------------------------------------

    task jtag_step;
        input tms_value;
        input tdi_value;

        begin
            @(negedge tck);

            tms = tms_value;
            tdi = tdi_value;

            @(posedge tck);
            #1;
        end
    endtask

    // ------------------------------------------------
    // ENTER SHIFT-IR STATE
    // Assumes TAP is in RUN_TEST_IDLE
    // ------------------------------------------------

    task enter_shift_ir;

        begin
            jtag_step(1'b1, 1'b0);
            jtag_step(1'b1, 1'b0);
            jtag_step(1'b0, 1'b0);
            jtag_step(1'b0, 1'b0);
        end

    endtask

    // ------------------------------------------------
    // LOAD INSTRUCTION
    // Instruction bits transmitted LSB first
    // ------------------------------------------------

    task load_instruction;
        input [3:0] instruction;

        begin

            enter_shift_ir();

            for (integer k = 0; k < 4; k = k + 1) begin

                jtag_step(
                    (k == 3),
                    instruction[k]
                );

            end

            // EXIT1_IR -> UPDATE_IR
            jtag_step(1'b1, 1'b0);

            // UPDATE_IR -> RUN_TEST_IDLE
            jtag_step(1'b0, 1'b0);

        end

    endtask

    // ------------------------------------------------
    // ENTER SHIFT-DR STATE
    // Assumes TAP is in RUN_TEST_IDLE
    // ------------------------------------------------

    task enter_shift_dr;

        begin
            jtag_step(1'b1, 1'b0);
            jtag_step(1'b0, 1'b0);
            jtag_step(1'b0, 1'b0);
        end

    endtask

    // ------------------------------------------------
    // SHIFT DATA
    //
    // msb_first = 0: LSB first
    // msb_first = 1: MSB first
    //
    // TDO is sampled before the rising edge.
    // ------------------------------------------------

    task shift_dr_stream;
        input [31:0] tx_data;
        input integer count;
        input integer msb_first;
        output [31:0] rx_data;

        reg tx_bit;
        reg rx_bit;

        begin

            rx_data = 32'b0;

            enter_shift_dr();

            for (integer k = 0; k < count; k = k + 1) begin

                if (msb_first)
                    tx_bit = tx_data[count-1-k];
                else
                    tx_bit = tx_data[k];

                @(negedge tck);

                tms = (k == count-1);
                tdi = tx_bit;

                #1;
                rx_bit = tdo;

                rx_data[k] = rx_bit;

                @(posedge tck);
                #1;

            end

            // EXIT1_DR -> UPDATE_DR
            jtag_step(1'b1, 1'b0);

            // UPDATE_DR -> RUN_TEST_IDLE
            // Update register samples update_dr here.
            jtag_step(1'b0, 1'b0);

        end

    endtask

    // ------------------------------------------------
    // MAIN TEST
    // ------------------------------------------------

    initial begin

        $dumpfile("waves/jtag_top.vcd");
        $dumpvars(0, tb_jtag_top);

        tck = 0;
        trst_n = 0;
        tms = 0;
        tdi = 0;

        pin_in = 8'h3C;
        system_out = 8'h96;

        passed = 0;
        failed = 0;

        received_data = 0;

        $display("");
        $display("======================================");
        $display("     INTEGRATED JTAG TOP TEST");
        $display("======================================");

        // --------------------------------------------
        // TEST 1: TAP RESET
        // --------------------------------------------

        #12;
        trst_n = 1;
        #2;

        check(
            tap_state == 4'd0,
            "TAP enters TEST_LOGIC_RESET"
        );

        check(
            current_instruction == 4'b0010,
            "Reset selects IDCODE instruction"
        );

        // --------------------------------------------
        // TEST 2: IDCODE
        // --------------------------------------------

        $display("");
        $display("---------- IDCODE TEST ----------");

        shift_dr_stream(
            IDCODE_VALUE,
            32,
            0,
            received_data
        );

        expected_data = IDCODE_VALUE;

        $display("Expected IDCODE : %h", expected_data);
        $display("Received IDCODE : %h", received_data);

        check(
            received_data == expected_data,
            "Complete 32-bit IDCODE serial read"
        );

        // --------------------------------------------
        // TEST 3: BYPASS
        // --------------------------------------------

        $display("");
        $display("---------- BYPASS TEST ----------");

        load_instruction(4'b1111);

        check(
            current_instruction == 4'b1111,
            "BYPASS instruction loaded"
        );

        shift_dr_stream(
            32'h00000001,
            2,
            0,
            received_data
        );

        $display("BYPASS received bits = %b",
                 received_data[1:0]);

        check(
            received_data[0] == 1'b0 &&
            received_data[1] == 1'b1,
            "BYPASS provides one-bit serial delay"
        );

        // --------------------------------------------
        // TEST 4: EXTEST
        // --------------------------------------------

        $display("");
        $display("---------- EXTEST TEST ----------");

        load_instruction(4'b0000);

        check(
            current_instruction == 4'b0000,
            "EXTEST instruction loaded"
        );

        // Send pattern MSB first.
        // Expected parallel output = A5.

        shift_dr_stream(
            32'h000000A5,
            8,
            1,
            received_data
        );

        #1;

        $display("Expected pin_out = A5");
        $display("Actual   pin_out = %h", pin_out);

        check(
            pin_out == 8'hA5,
            "EXTEST controls all eight output pins"
        );

        // --------------------------------------------
        // TEST 5: SAMPLE
        // --------------------------------------------

        $display("");
        $display("---------- SAMPLE TEST ----------");

        load_instruction(4'b0001);

        check(
            current_instruction == 4'b0001,
            "SAMPLE instruction loaded"
        );

        // Set a new functional output.
        system_out = 8'h5A;

        #1;

        check(
            pin_out == 8'h5A,
            "SAMPLE preserves functional outputs"
        );

        // Capture and shift external pin values.
        pin_in = 8'hC3;

        shift_dr_stream(
            32'h00000000,
            8,
            1,
            received_data
        );

        check(
            pin_out == 8'h5A,
            "SAMPLE does not override functional outputs"
        );

        // --------------------------------------------
        // FINAL SUMMARY
        // --------------------------------------------

        $display("");
        $display("======================================");
        $display("          TEST SUMMARY");
        $display("======================================");

        $display("Passed : %0d", passed);
        $display("Failed : %0d", failed);

        if (failed == 0)
            $display("RESULT : ALL TESTS PASSED");
        else
            $display("RESULT : TESTS FAILED");

        $display("======================================");

        $finish;

    end

endmodule