
`timescale 1ns/1ps

module tb_jtag_board_extest_fault;

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

    reg [7:0] pattern_a;
    reg [7:0] pattern_b;

    integer passed;
    integer failed;
    integer detected;
    integer total_faults;

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

    // Apply one JTAG clock cycle.
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

    // Enter SHIFT_IR.
    task enter_shift_ir;
        begin
            jtag_step(1'b1, 1'b0);
            jtag_step(1'b1, 1'b0);
            jtag_step(1'b0, 1'b0);
            jtag_step(1'b0, 1'b0);
        end
    endtask

    // Load instructions into both devices.
    task load_ir_chain;
        input [3:0] instr_a;
        input [3:0] instr_b;
        integer k;
        begin
            enter_shift_ir();

            // Device B first.
            for (k = 0; k < 4; k = k + 1)
                jtag_step(1'b0, instr_b[k]);

            // Device A second.
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

    // Enter SHIFT_DR.
    task enter_shift_dr;
        begin
            jtag_step(1'b1, 1'b0);
            jtag_step(1'b0, 1'b0);
            jtag_step(1'b0, 1'b0);
        end
    endtask

    // Load both boundary scan registers.
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

    // Capture parallel inputs and shift all 16 bits out.
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

            // EXIT1_DR -> UPDATE_DR -> RUN_TEST_IDLE
            jtag_step(1'b1, 1'b0);
            jtag_step(1'b0, 1'b0);
        end
    endtask

    task check_result;
        input condition;
        input string message;
        begin
            if (condition) begin
                $display("[PASS] %s", message);
                passed = passed + 1;
            end
            else begin
                $display("[FAIL] %s", message);
                failed = failed + 1;
            end
        end
    endtask

    // Check whether the captured data differs from normal data.
    task check_fault_detected;
        input [15:0] actual_data;
        input [15:0] expected_normal;
        input string fault_name;
        begin
            if (actual_data !== expected_normal) begin
                $display("[DETECTED] %s", fault_name);
                detected = detected + 1;
                passed = passed + 1;
            end
            else begin
                $display("[NOT DETECTED] %s", fault_name);
                failed = failed + 1;
            end
        end
    endtask

    initial begin

        tck = 0;
        trst_n = 0;
        tms = 0;
        tdi = 0;

        system_out_a = 8'h00;
        system_out_b = 8'h00;

        fault_enable = 0;
        fault_type = 0;
        fault_direction = 0;
        fault_bit_a = 0;
        fault_bit_b = 1;

        pattern_a = 8'hA5;
        pattern_b = 8'h5A;

        passed = 0;
        failed = 0;
        detected = 0;
        total_faults = 4;

        $dumpfile("waves/jtag_board_extest_fault.vcd");
        $dumpvars(0, tb_jtag_board_extest_fault);

        $display("");
        $display("========================================");
        $display(" JTAG EXTEST FAULT DETECTION TEST");
        $display("========================================");

        // Reset TAP controllers.
        repeat (5) @(posedge tck);
        #1;
        trst_n = 1;
        repeat (2) @(posedge tck);

        // Load EXTEST into both devices.
        load_ir_chain(4'b0000, 4'b0000);

        check_result(
            instruction_a == 4'b0000 &&
            instruction_b == 4'b0000,
            "EXTEST loaded into both devices"
        );

        // Load normal output patterns.
        load_bsr_chain(pattern_a, pattern_b);

        // TEST 1: Normal interconnect.
        fault_enable = 0;
        #2;
        load_bsr_chain(pattern_a, pattern_b);
        capture_and_read(received_data);

        $display("");
        $display("Normal captured data: %04h", received_data);

        check_result(
            received_data === 16'hA55A,
            "Normal interconnect captured correctly"
        );

        // TEST 2: A-to-B stuck-at-0 on bit 0.
        fault_enable = 1;
        fault_type = 3'd1;
        fault_direction = 0;
        fault_bit_a = 0;
        #2;
        load_bsr_chain(pattern_a, pattern_b);
        capture_and_read(received_data);

        $display("Stuck-at-0 captured data: %04h", received_data);

        check_fault_detected(
            received_data,
            16'hA55A,
            "A-to-B stuck-at-0"
        );

        check_result(
            received_data[8] === 1'b0,
            "Stuck-at-0 bit value captured correctly"
        );

        // TEST 3: B-to-A stuck-at-1 on bit 0.
        fault_type = 3'd2;
        fault_direction = 1;
        fault_bit_a = 0;
        #2;
        load_bsr_chain(pattern_a, pattern_b);
        capture_and_read(received_data);

        $display("Stuck-at-1 captured data: %04h", received_data);

        check_fault_detected(
            received_data,
            16'hA55A,
            "B-to-A stuck-at-1"
        );

        check_result(
            received_data[0] === 1'b1,
            "Stuck-at-1 bit value captured correctly"
        );

        // TEST 4: A-to-B open circuit on bit 2.
        fault_type = 3'd3;
        fault_direction = 0;
        fault_bit_a = 2;
        #2;
        load_bsr_chain(pattern_a, pattern_b);
        capture_and_read(received_data);

        $display("Open-circuit captured data: %04h", received_data);

        check_result(
            received_data[10] === 1'bz,
            "Open-circuit high-impedance condition captured"
        );

        if (received_data !== 16'hA55A) begin
            $display("[DETECTED] A-to-B open circuit");
            detected = detected + 1;
            passed = passed + 1;
        end
        else begin
            $display("[NOT DETECTED] A-to-B open circuit");
            failed = failed + 1;
        end

        // TEST 5: A-to-B bridging fault, bits 0 and 1.
        fault_type = 3'd4;
        fault_direction = 0;
        fault_bit_a = 0;
        fault_bit_b = 1;
        #2;
        load_bsr_chain(pattern_a, pattern_b);
        capture_and_read(received_data);

        $display("Bridging captured data: %04h", received_data);

        check_fault_detected(
            received_data,
            16'hA55A,
            "A-to-B bridging fault"
        );

        // Disable fault injection.
fault_enable = 0;
#2;

// Restore original boundary output patterns.
load_bsr_chain(pattern_a, pattern_b);

capture_and_read(received_data);

check_result(
    received_data === 16'hA55A,
    "Normal operation restored after fault disable"
);

        $display("");
        $display("========================================");
        $display("          FAULT COVERAGE REPORT");
        $display("========================================");

        $display("Total injected faults : %0d", total_faults);
        $display("Faults detected       : %0d", detected);
        $display("Faults undetected     : %0d",
                 total_faults - detected);

        $display("Fault coverage        : %0d%%",
                 (detected * 100) / total_faults);

        $display("----------------------------------------");
        $display("Passed : %0d", passed);
        $display("Failed : %0d", failed);
        $display("----------------------------------------");

        if (failed == 0)
            $display("RESULT : ALL TESTS PASSED");
        else
            $display("RESULT : TESTS FAILED");

        $finish;
    end

endmodule
