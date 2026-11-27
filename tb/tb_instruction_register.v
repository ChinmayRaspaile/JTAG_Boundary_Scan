
`timescale 1ns/1ps

module tb_instruction_register;

    reg tck;
    reg trst_n;
    reg capture_ir;
    reg shift_ir;
    reg update_ir;
    reg tdi;

    wire tdo;
    wire [3:0] current_instruction;

    integer passed;
    integer failed;

    instruction_register dut (
        .tck(tck),
        .trst_n(trst_n),
        .capture_ir(capture_ir),
        .shift_ir(shift_ir),
        .update_ir(update_ir),
        .tdi(tdi),
        .tdo(tdo),
        .current_instruction(current_instruction)
    );

    always #5 tck = ~tck;

    task check_instruction;
        input [3:0] expected;
        input [200*8:1] test_name;

        begin
            if (current_instruction === expected) begin
                $display("[PASS] %0s", test_name);
                passed = passed + 1;
            end
            else begin
                $display("[FAIL] %0s Expected=%b Actual=%b",
                         test_name, expected, current_instruction);
                failed = failed + 1;
            end
        end
    endtask

    task clock_ir;
        input capture;
        input shift;
        input update;
        input serial_in;

        begin
            @(negedge tck);
            capture_ir = capture;
            shift_ir   = shift;
            update_ir  = update;
            tdi        = serial_in;

            @(posedge tck);
            #1;
        end
    endtask

    initial begin

        $dumpfile("waves/instruction_register.vcd");
        $dumpvars(0, tb_instruction_register);

        tck = 0;
        trst_n = 0;

        capture_ir = 0;
        shift_ir = 0;
        update_ir = 0;
        tdi = 0;

        passed = 0;
        failed = 0;

        $display("\n==================================");
        $display("    JTAG INSTRUCTION REGISTER");
        $display("==================================");

        #2;

        check_instruction(4'b0010, "Reset selects IDCODE");

        trst_n = 1;

        // Capture IR
        clock_ir(1, 0, 0, 0);

        if (dut.shift_reg === 4'b0001) begin
            $display("[PASS] IR capture pattern = 0001");
            passed = passed + 1;
        end
        else begin
            $display("[FAIL] IR capture pattern");
            failed = failed + 1;
        end

        // Shift in EXTEST = 0000
        clock_ir(0, 1, 0, 0);
        clock_ir(0, 1, 0, 0);
        clock_ir(0, 1, 0, 0);
        clock_ir(0, 1, 0, 0);

        // Active instruction must remain IDCODE
        check_instruction(4'b0010, "Instruction unchanged during shifting");

        // Update instruction
        clock_ir(0, 0, 1, 0);

        check_instruction(4'b0000, "EXTEST instruction loaded");

        // Load SAMPLE = 0001
        clock_ir(1, 0, 0, 0);

        clock_ir(0, 1, 0, 1);
        clock_ir(0, 1, 0, 0);
        clock_ir(0, 1, 0, 0);
        clock_ir(0, 1, 0, 0);

        clock_ir(0, 0, 1, 0);

        check_instruction(4'b0001, "SAMPLE instruction loaded");

        // Load BYPASS = 1111
        clock_ir(1, 0, 0, 0);

        clock_ir(0, 1, 0, 1);
        clock_ir(0, 1, 0, 1);
        clock_ir(0, 1, 0, 1);
        clock_ir(0, 1, 0, 1);

        clock_ir(0, 0, 1, 0);

        check_instruction(4'b1111, "BYPASS instruction loaded");

        // Load IDCODE = 0010
        clock_ir(1, 0, 0, 0);

        clock_ir(0, 1, 0, 0);
        clock_ir(0, 1, 0, 1);
        clock_ir(0, 1, 0, 0);
        clock_ir(0, 1, 0, 0);

        clock_ir(0, 0, 1, 0);

        check_instruction(4'b0010, "IDCODE instruction loaded");

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
