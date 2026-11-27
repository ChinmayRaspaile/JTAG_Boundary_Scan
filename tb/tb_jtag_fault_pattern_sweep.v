
`timescale 1ns/1ps

module tb_jtag_fault_pattern_sweep;

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

    reg expected_fault_value;

    integer passed;
    integer failed;
    integer total_faults;
    integer detected;

    integer direction;
    integer fault;
    integer bit_index;

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

        passed = 0;
        failed = 0;
        detected = 0;
        total_faults = 0;

        $dumpfile("waves/jtag_fault_pattern_sweep.vcd");
        $dumpvars(0, tb_jtag_fault_pattern_sweep);

        $display("");
        $display("==============================================");
        $display(" JTAG AUTOMATED STUCK-AT FAULT SWEEP");
        $display("==============================================");

        // Reset both TAP controllers.
        repeat (5) @(posedge tck);
        #1;
        trst_n = 1;
        repeat (2) @(posedge tck);

        // Select EXTEST in both devices.
        load_ir_chain(4'b0000, 4'b0000);

        if (instruction_a == 4'b0000 &&
            instruction_b == 4'b0000)
            $display("[PASS] EXTEST selected in both devices");
        else begin
            $display("[FAIL] EXTEST instruction selection");
            failed = failed + 1;
        end

        $display("");
        $display("Starting automated fault sweep...");
        $display("");

        // Direction 0 = A-to-B.
        // Direction 1 = B-to-A.
        for (direction = 0; direction < 2;
             direction = direction + 1) begin

            for (fault = 1; fault <= 2;
                 fault = fault + 1) begin

                for (bit_index = 0; bit_index < 8;
                     bit_index = bit_index + 1) begin

                    total_faults = total_faults + 1;

                    fault_enable = 1'b1;
                    fault_type = fault;
                    fault_direction = direction;
                    fault_bit_a = bit_index;
                    fault_bit_b = 1;

                    // Stuck-at-0 requires driving logic 1.
                    // Stuck-at-1 requires driving logic 0.
                    if (fault == 1) begin
                        pattern_a = 8'hFF;
                        pattern_b = 8'hFF;
                        expected_fault_value = 1'b0;
                    end
                    else begin
                        pattern_a = 8'h00;
                        pattern_b = 8'h00;
                        expected_fault_value = 1'b1;
                    end

                    // Restore the original output pattern
                    // before every capture operation.
                    load_bsr_chain(pattern_a, pattern_b);

                    // Build expected normal capture signature.
                    expected_data = {pattern_a, pattern_b};

                    // Inject the expected faulty value into
                    // the corresponding captured input bit.
                    if (direction == 0)
                        expected_data[8 + bit_index] =
                            expected_fault_value;
                    else
                        expected_data[bit_index] =
                            expected_fault_value;

                    // Capture the two BSR input registers.
                    capture_and_read(received_data);

                    if (received_data === expected_data) begin

                        detected = detected + 1;
                        passed = passed + 1;

                        $display(
                            "[DETECTED] DIR=%0d FAULT=%0d BIT=%0d DATA=%04h",
                            direction,
                            fault,
                            bit_index,
                            received_data
                        );

                    end
                    else begin

                        failed = failed + 1;

                        $display(
                            "[FAIL] DIR=%0d FAULT=%0d BIT=%0d EXPECTED=%04h ACTUAL=%04h",
                            direction,
                            fault,
                            bit_index,
                            expected_data,
                            received_data
                        );

                    end

                end
            end
        end

        // Disable fault injection.
        fault_enable = 0;

        $display("");
        $display("==============================================");
        $display("       AUTOMATED FAULT COVERAGE REPORT");
        $display("==============================================");

        $display("Total fault cases : %0d", total_faults);
        $display("Detected faults   : %0d", detected);
        $display("Undetected faults : %0d",
                 total_faults - detected);

        if (total_faults != 0)
            $display("Fault coverage    : %0d%%",
                     (detected * 100) / total_faults);
        else
            $display("Fault coverage    : N/A");

        $display("----------------------------------------------");
        $display("Passed : %0d", passed);
        $display("Failed : %0d", failed);
        $display("----------------------------------------------");

        if (failed == 0 && detected == total_faults)
            $display("RESULT : ALL TESTS PASSED");
        else
            $display("RESULT : TESTS FAILED");

        $finish;
    end

endmodule
