`timescale 1ns/1ps

module tb_boundary_scan_register;

    localparam WIDTH = 8;

    reg tck;
    reg trst_n;

    reg capture_dr;
    reg shift_dr;
    reg update_dr;

    reg tdi;

    reg [WIDTH-1:0] pin_in;
    reg [WIDTH-1:0] system_out;

    reg extest_enable;

    wire tdo;
    wire [WIDTH-1:0] pin_out;

    integer passed;
    integer failed;
    integer i;

    reg [WIDTH-1:0] captured_value;
    reg [WIDTH-1:0] expected_pattern;

    boundary_scan_register #(
        .WIDTH(WIDTH)
    ) uut (
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

        $dumpfile("waves/boundary_scan_register.vcd");
        $dumpvars(0, tb_boundary_scan_register);

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

        captured_value = 8'b10110110;
        expected_pattern = 8'b11001010;

        $display("");
        $display("======================================");
        $display("  BOUNDARY SCAN REGISTER TEST");
        $display("======================================");

        // TEST 1: RESET

        #12;
        trst_n = 1;
        #2;

        check(tdo == 0, "Reset clears serial chain");

        // TEST 2: CAPTURE

        @(negedge tck);

        pin_in = captured_value;
        capture_dr = 1;

        @(posedge tck);
        #1;

        check(tdo == captured_value[7],
              "Capture loads all eight boundary cells");

        @(negedge tck);
        capture_dr = 0;

        // TEST 3: SHIFT OUT CAPTURED DATA

        shift_dr = 1;

        for (i = 0; i < WIDTH; i = i + 1) begin

            #1;

            check(tdo == captured_value[7-i],
                  "Serial output matches captured data");

            @(posedge tck);
            #1;

            @(negedge tck);

        end

        shift_dr = 0;

        // TEST 4: SHIFT NEW PATTERN INTO BSR

        for (i = 0; i < WIDTH; i = i + 1) begin

            tdi = (expected_pattern >> (7-i)) & 1'b1;
            shift_dr = 1;

            @(posedge tck);
            #1;

            @(negedge tck);

        end

        shift_dr = 0;
        tdi = 0;

        // TEST 5: DEBUG SHIFT REGISTERS

        $display("");
        $display("---------- SHIFT REGISTER DEBUG ----------");

        $display("Cell 0 = %b", uut.BSR_CELLS[0].u_cell.shift_reg);
        $display("Cell 1 = %b", uut.BSR_CELLS[1].u_cell.shift_reg);
        $display("Cell 2 = %b", uut.BSR_CELLS[2].u_cell.shift_reg);
        $display("Cell 3 = %b", uut.BSR_CELLS[3].u_cell.shift_reg);
        $display("Cell 4 = %b", uut.BSR_CELLS[4].u_cell.shift_reg);
        $display("Cell 5 = %b", uut.BSR_CELLS[5].u_cell.shift_reg);
        $display("Cell 6 = %b", uut.BSR_CELLS[6].u_cell.shift_reg);
        $display("Cell 7 = %b", uut.BSR_CELLS[7].u_cell.shift_reg);

        $display("------------------------------------------");

        // TEST 6: UPDATE OUTPUT LATCHES

        update_dr = 1;

        @(posedge tck);
        #1;

        extest_enable = 1;
        #1;

        $display("");
        $display("---------- OUTPUT DEBUG ----------");

        $display("Expected pin_out = %b", expected_pattern);
        $display("Actual   pin_out = %b", pin_out);

        $display("Cell 0 update = %b", uut.BSR_CELLS[0].u_cell.update_reg);
        $display("Cell 1 update = %b", uut.BSR_CELLS[1].u_cell.update_reg);
        $display("Cell 2 update = %b", uut.BSR_CELLS[2].u_cell.update_reg);
        $display("Cell 3 update = %b", uut.BSR_CELLS[3].u_cell.update_reg);
        $display("Cell 4 update = %b", uut.BSR_CELLS[4].u_cell.update_reg);
        $display("Cell 5 update = %b", uut.BSR_CELLS[5].u_cell.update_reg);
        $display("Cell 6 update = %b", uut.BSR_CELLS[6].u_cell.update_reg);
        $display("Cell 7 update = %b", uut.BSR_CELLS[7].u_cell.update_reg);

        $display("----------------------------------");

        check(pin_out == expected_pattern,
              "Update loads shifted pattern into output pins");

        @(negedge tck);
        update_dr = 0;

        // TEST 7: NORMAL MODE

        system_out = 8'b01010101;
        extest_enable = 0;

        #1;

        check(pin_out == 8'b01010101,
              "Normal mode selects functional outputs");

        // TEST 8: EXTEST MODE

        extest_enable = 1;

        #1;

        check(pin_out == expected_pattern,
              "EXTEST selects boundary scan outputs");

        // TEST 9: SECOND CAPTURE

        @(negedge tck);

        pin_in = 8'b11110000;
        capture_dr = 1;

        @(posedge tck);
        #1;

        check(tdo == 1'b1,
              "Second capture updates serial output");

        @(negedge tck);
        capture_dr = 0;

        // FINAL SUMMARY

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