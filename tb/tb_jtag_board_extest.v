`timescale 1ns/1ps

module tb_jtag_board_extest;

    reg tck;
    reg trst_n;
    reg tms;
    reg tdi;

    reg [7:0] system_out_a;
    reg [7:0] system_out_b;

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

    integer i;
    integer passed;
    integer failed;

    jtag_board_extest uut (
        .tck(tck),
        .trst_n(trst_n),
        .tms(tms),
        .tdi(tdi),
        .system_out_a(system_out_a),
        .system_out_b(system_out_b),
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

            // Device B receives its instruction first.
            for (k = 0; k < 4; k = k + 1)
                jtag_step(1'b0, instr_b[k]);

            // Device A receives its instruction second.
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

            // Device B data is shifted in first, MSB first.
            for (k = 7; k >= 0; k = k - 1)
                jtag_step(1'b0, data_b[k]);

            // Device A data is shifted in second, MSB first.
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

            // Capture both devices' parallel inputs, then shift them out.
            for (k = 15; k >= 0; k = k - 1) begin
                if (k == 0)
                    jtag_step(1'b1, 1'b0);
                else begin
                    @(negedge tck);
                    tms = 1'b0;
                    tdi = 1'b0;
                    #1;
                    data[k] = tdo;
                    @(posedge tck);
                    #1;
                end
            end

            // The final bit was sampled before its shift edge.
            // Complete the TAP state transitions.
            jtag_step(1'b1, 1'b0);
            jtag_step(1'b0, 1'b0);
        end
    endtask

    task check_result;
        input condition;
        input [255:0] message;
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
        tck = 1'b0;
        trst_n = 1'b0;
        tms = 1'b0;
        tdi = 1'b0;

        system_out_a = 8'h00;
        system_out_b = 8'h00;

        pattern_a = 8'hA5;
        pattern_b = 8'h5A;

        passed = 0;
        failed = 0;

        $dumpfile("waves/jtag_board_extest.vcd");
        $dumpvars(0, tb_jtag_board_extest);

        $display("");
        $display("========================================");
        $display(" JTAG EXTEST BOARD INTERCONNECT TEST");
        $display("========================================");

        repeat (5) @(posedge tck);
        #1;
        trst_n = 1'b1;
        repeat (2) @(posedge tck);

        check_result(
            tap_state_a == 4'd1 && tap_state_b == 4'd1,
            "Both TAP controllers enter RUN_TEST_IDLE"
        );

        load_ir_chain(4'b0000, 4'b0000);

        check_result(
            instruction_a == 4'b0000 && instruction_b == 4'b0000,
            "EXTEST instruction loaded into both devices"
        );

        load_bsr_chain(pattern_a, pattern_b);

        check_result(
            pin_out_a == pattern_a,
            "Device A boundary outputs updated"
        );

        check_result(
            pin_out_b == pattern_b,
            "Device B boundary outputs updated"
        );

        check_result(
            pin_in_b == pattern_a,
            "Board interconnect carries Device A outputs to Device B inputs"
        );

        check_result(
            pin_in_a == pattern_b,
            "Board interconnect carries Device B outputs to Device A inputs"
        );

        capture_and_read(received_data);

        $display("");
        $display("Device A output pattern : %02h", pattern_a);
        $display("Device B output pattern : %02h", pattern_b);
        $display("Captured serial data    : %04h", received_data);

        check_result(
            received_data[15:8] == pattern_a,
            "EXTEST captures Device A to Device B interconnect"
        );

        check_result(
            received_data[7:0] == pattern_b,
            "EXTEST captures Device B to Device A interconnect"
        );

        $display("");
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