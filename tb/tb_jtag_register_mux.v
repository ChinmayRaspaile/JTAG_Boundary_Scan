
`timescale 1ns/1ps

module tb_jtag_register_mux;

    reg [3:0] instruction;

    reg tdo_bypass;
    reg tdo_idcode;
    reg tdo_boundary;

    wire selected_tdo;

    wire select_bypass;
    wire select_idcode;
    wire select_boundary;

    integer passed;
    integer failed;

    jtag_register_mux dut (
        .instruction(instruction),

        .tdo_bypass(tdo_bypass),
        .tdo_idcode(tdo_idcode),
        .tdo_boundary(tdo_boundary),

        .selected_tdo(selected_tdo),

        .select_bypass(select_bypass),
        .select_idcode(select_idcode),
        .select_boundary(select_boundary)
    );

    task check_result;

        input expected_tdo;
        input expected_bypass;
        input expected_idcode;
        input expected_boundary;

        input [200*8:1] test_name;

        begin

            #1;

            if (
                selected_tdo === expected_tdo &&
                select_bypass === expected_bypass &&
                select_idcode === expected_idcode &&
                select_boundary === expected_boundary
            ) begin

                $display("[PASS] %0s", test_name);
                passed = passed + 1;

            end
            else begin

                $display("[FAIL] %0s", test_name);

                $display("TDO=%b BYPASS=%b IDCODE=%b BOUNDARY=%b",
                         selected_tdo,
                         select_bypass,
                         select_idcode,
                         select_boundary);

                failed = failed + 1;

            end

        end

    endtask

    initial begin

        $dumpfile("waves/jtag_register_mux.vcd");
        $dumpvars(0, tb_jtag_register_mux);

        passed = 0;
        failed = 0;

        tdo_bypass = 1'b1;
        tdo_idcode = 1'b0;
        tdo_boundary = 1'b1;

        $display("\n==================================");
        $display("     JTAG REGISTER MUX TEST");
        $display("==================================");

        // EXTEST
        instruction = 4'b0000;

        check_result(1'b1, 0, 0, 1,
                     "EXTEST selects boundary register");

        // SAMPLE
        instruction = 4'b0001;

        check_result(1'b1, 0, 0, 1,
                     "SAMPLE selects boundary register");

        // IDCODE
        instruction = 4'b0010;

        check_result(1'b0, 0, 1, 0,
                     "IDCODE selects IDCODE register");

        // BYPASS
        instruction = 4'b1111;

        check_result(1'b1, 1, 0, 0,
                     "BYPASS selects bypass register");

        // Invalid instruction
        instruction = 4'b0101;

        check_result(1'b1, 1, 0, 0,
                     "Invalid instruction defaults to BYPASS");

        // Verify data routing
        tdo_bypass = 0;

        check_result(0, 1, 0, 0,
                     "BYPASS data routing");

        instruction = 4'b0010;
        tdo_idcode = 1;

        check_result(1, 0, 1, 0,
                     "IDCODE data routing");

        instruction = 4'b0000;
        tdo_boundary = 0;

        check_result(0, 0, 0, 1,
                     "Boundary data routing");

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
