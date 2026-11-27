
`timescale 1ns/1ps

module tb_jtag_bridging_fault_sweep;

    reg tck;
    reg trst_n;
    reg tms;
    reg tdi;

    reg [7:0] system_out_a;
    reg [7:0] system_out_b;

    reg fault_enable;
    reg [2:0] fault_type;
    reg fault_direction;
    reg [3:0] fault_bit_a;
    reg [3:0] fault_bit_b;

    wire tdo;

    wire [7:0] pin_out_a;
    wire [7:0] pin_out_b;
    wire [7:0] pin_in_a;
    wire [7:0] pin_in_b;

    wire [3:0] instruction_a;
    wire [3:0] instruction_b;
    wire [3:0] tap_state_a;
    wire [3:0] tap_state_b;

    reg [15:0] received_data;
    reg [15:0] expected_data;

    reg [7:0] pattern_a;
    reg [7:0] pattern_b;

    reg bridge_value;

    integer passed;
    integer failed;
    integer total_faults;
    integer detected;

    integer direction;
    integer bridge_type;
    integer bit_i;
    integer bit_j;

    jtag_board_extest_fault uut (
        .tck(tck),
        .trst_n(trst_n),
        .tms(tms),
        .tdi(tdi),

        .system_out_a(system_out_a),
        .system_out_b(system_out_b),

        .fault_enable(fault_enable),
        .fault_type(fault_type),
        .fault_direction(fault_direction),
        .fault_bit_a(fault_bit_a),
        .fault_bit_b(fault_bit_b),

        .tdo(tdo),

        .pin_out_a(pin_out_a),
        .pin_out_b(pin_out_b),
        .pin_in_a(pin_in_a),
        .pin_in_b(pin_in_b),

        .instruction_a(instruction_a),
        .instruction_b(instruction_b),

        .tap_state_a(tap_state_a),
        .tap_state_b(tap_state_b)
    );

    always #5 tck = ~tck;

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

    task enter_shift_ir;
        begin
            jtag_step(1'b1, 1'b0);
            jtag_step(1'b1, 1'b0);
            jtag_step(1'b0, 1'b0);
            jtag_step(1'b0, 1'b0);
        end
    endtask

    task load_ir_chain;
        input [3:0] instr_a;
        input [3:0] instr_b;
        integer k;
        begin
            enter_shift_ir();

            // Device B receives instruction first.
            for (k = 0; k < 4; k = k + 1)
                jtag_step(1'b0, instr_b[k]);

            // Device A receives instruction second.
            for (k = 0; k < 4; k = k + 1) begin
                if (k == 3)
                    jtag_step(1'b1, instr_a[k]);
                else
                    jtag_step(1'b0, instr_a[k]);
            end

            jtag_step(1'b1, 1'b0);
            jtag_step(1'b0, 1'b0);
        end
    endtask

    task enter_shift_dr;
        begin
            jtag_step(1'b1, 1'b0);
            jtag_step(1'b0, 1'b0);
            jtag_step(1'b0, 1'b0);
        end
    endtask

    task load_bsr_chain;
        input [7:0] data_a;
        input [7:0] data_b;
        integer k;
        begin
            enter_shift_dr();

            // Device B first, MSB first.
            for (k = 7; k >= 0; k = k - 1)
                jtag_step(1'b0, data_b[k]);

            // Device A second, MSB first.
            for (k = 7; k >= 0; k = k - 1) begin
                if (k == 0)
                    jtag_step(1'b1, data_a[k]);
                else
                    jtag_step(1'b0, data_a[k]);
            end

            jtag_step(1'b1, 1'b0);
            jtag_step(1'b0, 1'b0);
        end
    endtask

    task capture_and_read;
        output [15:0] data;
        integer k;
        begin
            data = 16'h0000;

            enter_shift_dr();

            for (k = 15; k >= 0; k = k - 1) begin
                @(negedge tck);

                if (k == 0)
                    tms = 1'b1;
                else
                    tms = 1'b0;

                tdi = 1'b0;

                #1;
                data[k] = tdo;

                @(posedge tck);
                #1;
            end

            jtag_step(1'b1, 1'b0);
            jtag_step(1'b0, 1'b0);
        end
    endtask

    initial begin

        tck = 0;
        trst_n = 0;
        tms = 0;
        tdi = 0;

        system_out_a = 0;
        system_out_b = 0;

        fault_enable = 0;
        fault_type = 0;
        fault_direction = 0;
        fault_bit_a = 0;
        fault_bit_b = 1;

        pattern_a = 0;
        pattern_b = 0;
        bridge_value = 0;

        passed = 0;
        failed = 0;
        detected = 0;
        total_faults = 0;

        $dumpfile("waves/jtag_bridging_fault_sweep.vcd");
        $dumpvars(0, tb_jtag_bridging_fault_sweep);

        $display("");
        $display("================================================");
        $display(" JTAG AUTOMATED BRIDGING FAULT PATTERN SWEEP");
        $display("================================================");

        // Reset both TAP controllers.
        repeat (5) @(posedge tck);
        #1;
        trst_n = 1;
        repeat (2) @(posedge tck);

        // Select EXTEST in both devices.
        load_ir_chain(4'b0000, 4'b0000);

        if (instruction_a == 4'b0000 &&
            instruction_b == 4'b0000) begin
            $display("[PASS] EXTEST selected in both devices");
            passed = passed + 1;
        end
        else begin
            $display("[FAIL] EXTEST instruction selection");
            failed = failed + 1;
        end

        $display("");
        $display("Starting 112 bridging fault tests...");
        $display("");

        // Direction 0 = A-to-B.
        // Direction 1 = B-to-A.
        for (direction = 0; direction < 2;
             direction = direction + 1) begin

            // Type 4 = wired-AND.
            // Type 5 = wired-OR.
            for (bridge_type = 4; bridge_type <= 5;
                 bridge_type = bridge_type + 1) begin

                // Test every unique pair of bits.
                for (bit_i = 0; bit_i < 8;
                     bit_i = bit_i + 1) begin

                    for (bit_j = bit_i + 1; bit_j < 8;
                         bit_j = bit_j + 1) begin

                        total_faults = total_faults + 1;

                        fault_enable = 1'b1;
                        fault_type = bridge_type;
                        fault_direction = direction;
                        fault_bit_a = bit_i;
                        fault_bit_b = bit_j;

                        // Drive bit_i HIGH and bit_j LOW.
                        pattern_a = 8'h00;
                        pattern_b = 8'h00;

                        if (direction == 0)
                            pattern_a[bit_i] = 1'b1;
                        else
                            pattern_b[bit_i] = 1'b1;

                        // Reload boundary registers before
                        // each capture operation.
                        load_bsr_chain(pattern_a, pattern_b);

                        // Start with the normal expected signature.
                        expected_data = {pattern_a, pattern_b};

                        // Calculate the expected bridge value.
                        if (bridge_type == 4)
                            bridge_value = 1'b0;
                        else
                            bridge_value = 1'b1;

                        // Modify the two affected captured bits.
                        if (direction == 0) begin
                            expected_data[8 + bit_i] =
                                bridge_value;

                            expected_data[8 + bit_j] =
                                bridge_value;
                        end
                        else begin
                            expected_data[bit_i] =
                                bridge_value;

                            expected_data[bit_j] =
                                bridge_value;
                        end

                        // Capture and shift out both BSRs.
                        capture_and_read(received_data);

                        if (received_data === expected_data) begin

                            detected = detected + 1;
                            passed = passed + 1;

                            $display(
                                "[DETECTED] DIR=%0d TYPE=%0d PAIR=%0d-%0d DATA=%04h",
                                direction,
                                bridge_type,
                                bit_i,
                                bit_j,
                                received_data
                            );

                        end
                        else begin

                            failed = failed + 1;

                            $display(
                                "[FAIL] DIR=%0d TYPE=%0d PAIR=%0d-%0d EXPECTED=%04h ACTUAL=%04h",
                                direction,
                                bridge_type,
                                bit_i,
                                bit_j,
                                expected_data,
                                received_data
                            );

                        end

                    end
                end
            end
        end

        // Disable fault injection.
        fault_enable = 0;

        // Verify normal operation is restored.
        pattern_a = 8'hA5;
        pattern_b = 8'h5A;

        load_bsr_chain(pattern_a, pattern_b);
        capture_and_read(received_data);

        expected_data = 16'hA55A;

        if (received_data === expected_data) begin
            $display("");
            $display("[PASS] Normal interconnect restored");
            passed = passed + 1;
        end
        else begin
            $display("[FAIL] Normal interconnect restoration");
            $display("Expected: %04h Actual: %04h",
                     expected_data, received_data);
            failed = failed + 1;
        end

        // Final report.
        $display("");
        $display("================================================");
        $display("       BRIDGING FAULT COVERAGE REPORT");
        $display("================================================");

        $display("Total fault cases : %0d", total_faults);
        $display("Detected faults   : %0d", detected);
        $display("Undetected faults : %0d",
                 total_faults - detected);

        if (total_faults != 0)
            $display("Fault coverage    : %0d%%",
                     (detected * 100) / total_faults);
        else
            $display("Fault coverage    : N/A");

        $display("-----------------------------------------------");
        $display("Passed : %0d", passed);
        $display("Failed : %0d", failed);
        $display("-----------------------------------------------");

        if (failed == 0 && detected == total_faults)
            $display("RESULT : ALL TESTS PASSED");
        else
            $display("RESULT : TESTS FAILED");

        $finish;
    end

endmodule
