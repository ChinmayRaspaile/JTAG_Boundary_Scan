
`timescale 1ns/1ps

module tb_idcode_register;

    reg tck;
    reg trst_n;
    reg capture_dr;
    reg shift_dr;
    reg tdi;

    wire tdo;

    reg [31:0] received_data;

    integer passed;
    integer failed;
    integer i;

    localparam [31:0] EXPECTED_IDCODE = 32'h12345679;

    idcode_register #(
        .IDCODE_VALUE(EXPECTED_IDCODE)
    ) dut (
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

    task clock_idcode;
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

        $dumpfile("waves/idcode_register.vcd");
        $dumpvars(0, tb_idcode_register);

        tck = 0;
        trst_n = 0;
        capture_dr = 0;
        shift_dr = 0;
        tdi = 0;

        passed = 0;
        failed = 0;
        received_data = 0;

        $display("\n==================================");
        $display("       JTAG IDCODE REGISTER");
        $display("==================================");

        #2;

        check_tdo(EXPECTED_IDCODE[0],
                  "Reset loads IDCODE");

        trst_n = 1;

        // Capture IDCODE
        clock_idcode(1, 0, 0);

        check_tdo(EXPECTED_IDCODE[0],
                  "Capture DR loads IDCODE");

        // Shift out all 32 bits, LSB first
        for (i = 0; i < 32; i = i + 1) begin

            received_data[i] = tdo;

            clock_idcode(0, 1, 0);

        end

        if (received_data === EXPECTED_IDCODE) begin
            $display("[PASS] Complete 32-bit IDCODE");
            passed = passed + 1;
        end
        else begin
            $display("[FAIL] IDCODE mismatch");
            $display("Expected: %h", EXPECTED_IDCODE);
            $display("Received: %h", received_data);
            failed = failed + 1;
        end

        // Check mandatory LSB
        if (received_data[0] === 1'b1) begin
            $display("[PASS] Mandatory IDCODE bit 0");
            passed = passed + 1;
        end
        else begin
            $display("[FAIL] Mandatory IDCODE bit 0");
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
