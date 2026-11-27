
`timescale 1ns/1ps

module tb_jtag_open_circuit_sweep;

    reg tck, trst_n, tms, tdi;

    reg [7:0] system_out_a;
    reg [7:0] system_out_b;

    reg fault_enable;
    reg [2:0] fault_type;
    reg fault_direction;
    reg [3:0] fault_bit_a;
    reg [3:0] fault_bit_b;

    wire tdo;

    wire [7:0] pin_out_a, pin_out_b;
    wire [7:0] pin_in_a, pin_in_b;

    wire [3:0] instruction_a, instruction_b;
    wire [3:0] tap_state_a, tap_state_b;

    reg [15:0] received_data;

    reg [7:0] pattern_a, pattern_b;

    integer passed, failed;
    integer detected, total_faults;
    integer direction, bit_index;

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
            jtag_step(1, 0);
            jtag_step(1, 0);
            jtag_step(0, 0);
            jtag_step(0, 0);
        end
    endtask

    task load_ir_chain;
        input [3:0] instr_a;
        input [3:0] instr_b;
        integer k;
        begin
            enter_shift_ir();

            for (k = 0; k < 4; k = k + 1)
                jtag_step(0, instr_b[k]);

            for (k = 0; k < 4; k = k + 1) begin
                if (k == 3)
                    jtag_step(1, instr_a[k]);
                else
                    jtag_step(0, instr_a[k]);
            end

            jtag_step(1, 0);
            jtag_step(0, 0);
        end
    endtask

    task enter_shift_dr;
        begin
            jtag_step(1, 0);
            jtag_step(0, 0);
            jtag_step(0, 0);
        end
    endtask

    task load_bsr_chain;
        input [7:0] data_a;
        input [7:0] data_b;
        integer k;
        begin
            enter_shift_dr();

            for (k = 7; k >= 0; k = k - 1)
                jtag_step(0, data_b[k]);

            for (k = 7; k >= 0; k = k - 1) begin
                if (k == 0)
                    jtag_step(1, data_a[k]);
                else
                    jtag_step(0, data_a[k]);
            end

            jtag_step(1, 0);
            jtag_step(0, 0);
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
                    tms = 1;
                else
                    tms = 0;

                tdi = 0;

                #1;
                data[k] = tdo;

                @(posedge tck);
                #1;
            end

            jtag_step(1, 0);
            jtag_step(0, 0);
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

        pattern_a = 8'hFF;
        pattern_b = 8'hFF;

        passed = 0;
        failed = 0;
        detected = 0;
        total_faults = 16;

        $dumpfile("waves/jtag_open_circuit_sweep.vcd");
        $dumpvars(0, tb_jtag_open_circuit_sweep);

        $display("");
        $display("==============================================");
        $display(" JTAG AUTOMATED OPEN-CIRCUIT FAULT SWEEP");
        $display("==============================================");

        repeat (5) @(posedge tck);
        #1;
        trst_n = 1;
        repeat (2) @(posedge tck);

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

        for (direction = 0; direction < 2;
             direction = direction + 1) begin

            for (bit_index = 0; bit_index < 8;
                 bit_index = bit_index + 1) begin

                fault_enable = 1;
                fault_type = 3'd3;
                fault_direction = direction;
                fault_bit_a = bit_index;

                #2;

                // Reload output patterns before each capture.
                load_bsr_chain(pattern_a, pattern_b);

                capture_and_read(received_data);

                if (direction == 0) begin

                    if (received_data[8 + bit_index] === 1'bz) begin
                        $display(
                            "[DETECTED] A->B OPEN BIT=%0d DATA=%04h",
                            bit_index, received_data
                        );
                        detected = detected + 1;
                        passed = passed + 1;
                    end
                    else begin
                        $display(
                            "[NOT DETECTED] A->B OPEN BIT=%0d DATA=%04h",
                            bit_index, received_data
                        );
                        failed = failed + 1;
                    end

                end
                else begin

                    if (received_data[bit_index] === 1'bz) begin
                        $display(
                            "[DETECTED] B->A OPEN BIT=%0d DATA=%04h",
                            bit_index, received_data
                        );
                        detected = detected + 1;
                        passed = passed + 1;
                    end
                    else begin
                        $display(
                            "[NOT DETECTED] B->A OPEN BIT=%0d DATA=%04h",
                            bit_index, received_data
                        );
                        failed = failed + 1;
                    end

                end

            end
        end

        fault_enable = 0;
        #2;

        load_bsr_chain(8'hA5, 8'h5A);
        capture_and_read(received_data);

        if (received_data === 16'hA55A) begin
            $display("[PASS] Normal operation restored");
            passed = passed + 1;
        end
        else begin
            $display("[FAIL] Normal operation restoration");
            failed = failed + 1;
        end

        $display("");
        $display("==============================================");
        $display("       OPEN-CIRCUIT COVERAGE REPORT");
        $display("==============================================");

        $display("Total fault cases : %0d", total_faults);
        $display("Detected faults   : %0d", detected);
        $display("Undetected faults : %0d",
                 total_faults - detected);

        $display("Fault coverage    : %0d%%",
                 (detected * 100) / total_faults);

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
