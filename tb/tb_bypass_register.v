
`timescale 1ns/1ps

module tb_bypass_register;

    reg tck;
    reg trst_n;
    reg capture_dr;
    reg shift_dr;
    reg tdi;

    wire tdo;

    integer passed;
    integer failed;

    bypass_register dut (
        .tck(tck),
        .trst_n(trst_n),
        .capture_dr(capture_dr),
        .shift_dr(shift_dr),
        .tdi(tdi),
        .tdo(tdo)
    );

    always #5 tck = ~tck;

    task check_tdo;
        input expected;
        input [200*8:1] test_name;

        begin
            if (tdo === expected) begin
                $display("[PASS] %0s", test_name);
                passed = passed + 1;
            end
            else begin
                $display("[FAIL] %0s Expected=%b Actual=%b",
                         test_name, expected, tdo);
                failed = failed + 1;
            end
        end
    endtask

    task clock_bypass;
        input capture;
        input shift;
        input serial_in;

        begin
            @(negedge tck);
            capture_dr = capture;
            shift_dr = shift;
            tdi = serial_in;

            @(posedge tck);
            #1;
        end
    endtask

    initial begin

        $dumpfile("waves/bypass_register.vcd");
        $dumpvars(0, tb_bypass_register);

        tck = 0;
        trst_n = 0;
        capture_dr = 0;
        shift_dr = 0;
        tdi = 0;

        passed = 0;
        failed = 0;

        $display("\n==================================");
        $display("       JTAG BYPASS REGISTER");
        $display("==================================");

        #2;
        check_tdo(1'b0, "Reset clears bypass register");

        trst_n = 1;

        // Capture DR
        clock_bypass(1, 0, 0);
        check_tdo(1'b0, "Capture DR loads zero");

        // Shift 1
        clock_bypass(0, 1, 1);
        check_tdo(1'b1, "Shift input 1");

        // Shift 0
        clock_bypass(0, 1, 0);
        check_tdo(1'b0, "Shift input 0");

        // Hold register when not shifting
        clock_bypass(0, 0, 1);
        check_tdo(1'b0, "Hold data when shift disabled");

        // Capture again
        clock_bypass(1, 0, 1);
        check_tdo(1'b0, "Capture resets bypass data");

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
