
`timescale 1ns/1ps

module tb_jtag_board;

    reg tck;
    reg trst_n;
    reg tms;
    reg tdi;

    reg [7:0] pin_in_a;
    reg [7:0] system_out_a;

    reg [7:0] pin_in_b;
    reg [7:0] system_out_b;

    wire tdo;

    wire [7:0] pin_out_a;
    wire [7:0] pin_out_b;

    wire [3:0] instruction_a;
    wire [3:0] instruction_b;

    wire [3:0] tap_state_a;
    wire [3:0] tap_state_b;

    reg [63:0] received_data;

    integer passed;
    integer failed;

    localparam [31:0] IDCODE_A = 32'h12345679;
    localparam [31:0] IDCODE_B = 32'h87654321;

    jtag_board uut (
        .tck(tck),
        .trst_n(trst_n),
        .tms(tms),
        .tdi(tdi),

        .pin_in_a(pin_in_a),
        .system_out_a(system_out_a),

        .pin_in_b(pin_in_b),
        .system_out_b(system_out_b),

        .tdo(tdo),

        .pin_out_a(pin_out_a),
        .pin_out_b(pin_out_b),

        .instruction_a(instruction_a),
        .instruction_b(instruction_b),

        .tap_state_a(tap_state_a),
        .tap_state_b(tap_state_b)
    );

    // Clock generation
    always #5 tck = ~tck;

    // Test checking task
    task check;
        input condition;
        input [8*100-1:0] test_name;
        begin
            if (condition) begin
                $display("[PASS] %0s", test_name);
                passed = passed + 1;
            end
            else begin
                $display("[FAIL] %0s", test_name);
                failed = failed + 1;
            end
        end
    endtask

    // JTAG clock step
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

    // Enter SHIFT_IR state
    task enter_shift_ir;
        begin
            jtag_step(1'b1, 1'b0);
            jtag_step(1'b1, 1'b0);
            jtag_step(1'b0, 1'b0);
            jtag_step(1'b0, 1'b0);
        end
    endtask

    // Load instructions into both devices
task load_ir_chain;
    input [3:0] instr_a;
    input [3:0] instr_b;
    integer k;
    begin
        enter_shift_ir();

        // First: Device B instruction
        for (k = 0; k < 4; k = k + 1) begin
            jtag_step(1'b0, instr_b[k]);
        end

        // Second: Device A instruction
        for (k = 0; k < 4; k = k + 1) begin
            if (k == 3)
                jtag_step(1'b1, instr_a[k]);
            else
                jtag_step(1'b0, instr_a[k]);
        end

        // EXIT1_IR -> UPDATE_IR -> RUN_TEST_IDLE
        jtag_step(1'b1, 1'b0);
        jtag_step(1'b0, 1'b0);
    end
endtask

    // Read 64-bit IDCODE chain
    task read_idcode_chain;
        output [63:0] rx_data;
        integer k;
        begin
            // RUN_TEST_IDLE -> SELECT_DR_SCAN
            jtag_step(1'b1, 1'b0);

            // SELECT_DR_SCAN -> CAPTURE_DR
            jtag_step(1'b0, 1'b0);

            // CAPTURE_DR -> SHIFT_DR
            jtag_step(1'b0, 1'b0);

            for (k = 0; k < 64; k = k + 1) begin
                @(negedge tck);

                if (k == 63)
                    tms = 1'b1;
                else
                    tms = 1'b0;

                tdi = 1'b0;
                #1;
                rx_data[k] = tdo;

                @(posedge tck);
                #1;
            end

            // EXIT1_DR -> UPDATE_DR -> RUN_TEST_IDLE
            jtag_step(1'b1, 1'b0);
            jtag_step(1'b0, 1'b0);
        end
    endtask

    initial begin

        $dumpfile("waves/jtag_board.vcd");
        $dumpvars(0, tb_jtag_board);

        tck = 1'b0;
        trst_n = 1'b0;
        tms = 1'b0;
        tdi = 1'b0;

        pin_in_a = 8'hA5;
        system_out_a = 8'h11;

        pin_in_b = 8'h5A;
        system_out_b = 8'h22;

        received_data = 64'b0;

        passed = 0;
        failed = 0;

        $display("");
        $display("======================================");
        $display("     TWO-DEVICE JTAG BOARD TEST");
        $display("======================================");

        // Reset both devices
        repeat (3) @(posedge tck);
        #1;
        trst_n = 1'b1;

        jtag_step(1'b0, 1'b0);

        check(tap_state_a == 4'd1 &&
              tap_state_b == 4'd1,
              "Both TAP controllers enter RUN_TEST_IDLE");

        check(instruction_a == 4'b0010 &&
              instruction_b == 4'b0010,
              "Both devices select IDCODE after reset");

        // Read both IDCODE registers
        $display("");
        $display("---------- IDCODE CHAIN TEST ----------");

        read_idcode_chain(received_data);

        $display("Expected Device B IDCODE : %08h", IDCODE_B);
        $display("Expected Device A IDCODE : %08h", IDCODE_A);
        $display("Received chain data      : %016h", received_data);

        check(received_data[31:0] == IDCODE_B,
              "Device B IDCODE received first");

        check(received_data[63:32] == IDCODE_A,
              "Device A IDCODE received second");

        // Load different instructions
        $display("");
        $display("---------- INSTRUCTION CHAIN TEST ----------");

        load_ir_chain(4'b0001, 4'b1111);

        $display("Device A instruction : %b", instruction_a);
        $display("Device B instruction : %b", instruction_b);

        check(instruction_a == 4'b0001,
              "Device A receives SAMPLE instruction");

        check(instruction_b == 4'b1111,
              "Device B receives BYPASS instruction");

        // Summary
        $display("");
        $display("======================================");
        $display("             TEST SUMMARY");
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
