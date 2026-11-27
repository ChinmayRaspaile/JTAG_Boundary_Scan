`timescale 1ns/1ps

module tb_boundary_scan_cell;

    reg tck;
    reg trst_n;

    reg capture_dr;
    reg shift_dr;
    reg update_dr;

    reg tdi;
    reg pin_in;
    reg system_out;
    reg extest_enable;

    wire tdo;
    wire pin_out;

    integer passed;
    integer failed;

    boundary_scan_cell uut (
        .tck(tck),
        .trst_n(trst_n),

        .capture_dr(capture_dr),
        .shift_dr(shift_dr),
        .update_dr(update_dr),

        .tdi(tdi),
        .pin_in(pin_in),
        .system_out(system_out),

        .extest_enable(extest_enable),

        .tdo(tdo),
        .pin_out(pin_out)
    );

    // 10 ns clock period
    always #5 tck = ~tck;

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

    initial begin

        $dumpfile("waves/boundary_scan_cell.vcd");
        $dumpvars(0, tb_boundary_scan_cell);

        tck = 0;
        trst_n = 0;

        capture_dr = 0;
        shift_dr = 0;
        update_dr = 0;

        tdi = 0;
        pin_in = 0;
        system_out = 0;
        extest_enable = 0;

        passed = 0;
        failed = 0;

        $display("");
        $display("======================================");
        $display("     BOUNDARY SCAN CELL TEST");
        $display("======================================");

        // Test 1: Reset
        #12;
        trst_n = 1;
        #2;

        check(tdo == 0, "Reset clears shift register");

        // Test 2: Capture external pin input
        @(negedge tck);
        pin_in = 1;
        capture_dr = 1;

        @(posedge tck);
        #1;

        check(tdo == 1, "Capture stores external pin input");

        @(negedge tck);
        capture_dr = 0;

        // Test 3: Shift serial data
        tdi = 0;
        shift_dr = 1;

        @(posedge tck);
        #1;

        check(tdo == 0, "Shift operation loads TDI");

        @(negedge tck);
        shift_dr = 0;

        // Test 4: Update output latch
        update_dr = 1;

        @(posedge tck);
        #1;

        extest_enable = 1;

        check(pin_out == 0, "Update latch stores shifted value");

        @(negedge tck);
        update_dr = 0;

        // Test 5: Normal functional output
        system_out = 1;
        extest_enable = 0;
        #1;

        check(pin_out == 1, "Normal mode selects system output");

        // Test 6: EXTEST output control
        extest_enable = 1;
        #1;

        check(pin_out == 0, "EXTEST mode selects boundary output");

        // Test 7: Capture a zero
        @(negedge tck);
        pin_in = 0;
        capture_dr = 1;

        @(posedge tck);
        #1;

        check(tdo == 0, "Capture correctly stores logic zero");

        @(negedge tck);
        capture_dr = 0;

        // Test 8: Shift and update a one
        tdi = 1;
        shift_dr = 1;

        @(posedge tck);
        #1;

        check(tdo == 1, "Shift operation loads logic one");

        @(negedge tck);
        shift_dr = 0;
        update_dr = 1;

        @(posedge tck);
        #1;

        check(pin_out == 1, "Updated boundary value drives output");

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