
`timescale 1ns/1ps

module tb_tap_controller;

    reg tck;
    reg trst_n;
    reg tms;

    wire capture_dr;
    wire shift_dr;
    wire update_dr;

    wire capture_ir;
    wire shift_ir;
    wire update_ir;

    wire test_logic_reset;
    wire run_test_idle;

    wire [3:0] current_state;

    integer passed;
    integer failed;

    tap_controller dut (
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

        .current_state(current_state)
    );

    always #5 tck = ~tck;

    task check_state;
        input [3:0] expected;
        input [200*8:1] test_name;

        begin
            if (current_state === expected) begin
                $display("[PASS] %0s", test_name);
                passed = passed + 1;
            end
            else begin
                $display("[FAIL] %0s Expected=%0d Actual=%0d",
                         test_name, expected, current_state);
                failed = failed + 1;
            end
        end
    endtask

    task step;
        input next_tms;

        begin
            @(negedge tck);
            tms = next_tms;

            @(posedge tck);
            #1;
        end
    endtask

    initial begin

        $dumpfile("waves/tap_controller.vcd");
        $dumpvars(0, tb_tap_controller);

        tck = 0;
        trst_n = 0;
        tms = 0;

        passed = 0;
        failed = 0;

        $display("\n==================================");
        $display("       JTAG TAP CONTROLLER TEST");
        $display("==================================");

        // Asynchronous reset
        #2;
        check_state(4'd0, "Asynchronous reset");

        trst_n = 1;

        // Reset -> Idle
        step(0);
        check_state(4'd1, "Reset to Run-Test/Idle");

        // Idle -> Select DR
        step(1);
        check_state(4'd2, "Idle to Select-DR");

        // Select DR -> Capture DR
        step(0);
        check_state(4'd3, "Select-DR to Capture-DR");

        // Capture DR -> Shift DR
        step(0);
        check_state(4'd4, "Capture-DR to Shift-DR");

        // Shift DR -> Exit1 DR
        step(1);
        check_state(4'd5, "Shift-DR to Exit1-DR");

        // Exit1 DR -> Pause DR
        step(0);
        check_state(4'd6, "Exit1-DR to Pause-DR");

        // Pause DR -> Exit2 DR
        step(1);
        check_state(4'd7, "Pause-DR to Exit2-DR");

        // Exit2 DR -> Update DR
        step(1);
        check_state(4'd8, "Exit2-DR to Update-DR");

        // Update DR -> Idle
        step(0);
        check_state(4'd1, "Update-DR to Idle");

        // Idle -> Select DR -> Select IR
        step(1);
        step(1);
        check_state(4'd9, "Select-DR to Select-IR");

        // Select IR -> Capture IR
        step(0);
        check_state(4'd10, "Select-IR to Capture-IR");

        // Capture IR -> Shift IR
        step(0);
        check_state(4'd11, "Capture-IR to Shift-IR");

        // Shift IR -> Exit1 IR
        step(1);
        check_state(4'd12, "Shift-IR to Exit1-IR");

        // Exit1 IR -> Pause IR
        step(0);
        check_state(4'd13, "Exit1-IR to Pause-IR");

        // Pause IR -> Exit2 IR
        step(1);
        check_state(4'd14, "Pause-IR to Exit2-IR");

        // Exit2 IR -> Update IR
        step(1);
        check_state(4'd15, "Exit2-IR to Update-IR");

        // Update IR -> Idle
        step(0);
        check_state(4'd1, "Update-IR to Idle");

        // Verify five TMS-high clocks reset TAP
        step(1);
        step(1);
        step(1);
        step(1);
        step(1);

        check_state(4'd0, "Five TMS-high clocks reset TAP");

        // Check state output decoding
        if (test_logic_reset === 1'b1) begin
            $display("[PASS] Reset state decode");
            passed = passed + 1;
        end
        else begin
            $display("[FAIL] Reset state decode");
            failed = failed + 1;
        end

        $display("\n==================================");
        $display("          TEST SUMMARY");
        $display("==================================");
        $display("Passed : %0d", passed);
        $display("Failed : %0d", failed);

        if (failed == 0)
            $display("RESULT : ALL TESTS PASSED");
        else
            $display("RESULT : TEST FAILED");

        $display("==================================\n");

        $finish;

    end

endmodule
