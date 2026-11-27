`timescale 1ns/1ps


module tb_board_interconnect_fault;

reg [7:0] device_a_out;
reg [7:0] device_b_out;

reg fault_enable;
reg [2:0] fault_type;
reg fault_direction;
reg [3:0] fault_bit_a;
reg [3:0] fault_bit_b;

wire [7:0] device_a_in;
wire [7:0] device_b_in;

integer passed;
integer failed;

board_interconnect_fault uut (
.device_a_out(device_a_out),
.device_b_out(device_b_out),
.fault_enable(fault_enable),
.fault_type(fault_type),
.fault_direction(fault_direction),
.fault_bit_a(fault_bit_a),
.fault_bit_b(fault_bit_b),
.device_a_in(device_a_in),
.device_b_in(device_b_in)
);

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

initial begin

passed = 0;
failed = 0;

device_a_out = 8'hA5;
device_b_out = 8'h5A;

fault_enable = 1'b0;
fault_type = 3'd0;
fault_direction = 1'b0;
fault_bit_a = 4'd0;
fault_bit_b = 4'd1;

$dumpfile("waves/board_interconnect_fault.vcd");
$dumpvars(0, tb_board_interconnect_fault);

$display("");
$display("========================================");
$display(" INTERCONNECT FAULT INJECTION TEST");
$display("========================================");

#10;

// Test 1: Normal interconnect
check_result(
device_b_in == 8'hA5 && device_a_in == 8'h5A,
"Normal bidirectional interconnect"
);

// Test 2: Stuck-at-0 on A-to-B bit 0
fault_enable = 1'b1;
fault_type = 3'd1;
fault_direction = 1'b0;
fault_bit_a = 4'd0;
#10;

check_result(
device_b_in[0] === 1'b0 &&
device_b_in[7:1] == device_a_out[7:1],
"Stuck-at-0 fault on A-to-B"
);

// Test 3: Stuck-at-1 on B-to-A bit 1
fault_type = 3'd2;
fault_direction = 1'b1;
fault_bit_a = 4'd1;
#10;

check_result(
device_a_in[1] === 1'b1 &&
device_a_in[7:2] == device_b_out[7:2] &&
device_a_in[0] == device_b_out[0],
"Stuck-at-1 fault on B-to-A"
);

// Test 4: Open circuit on A-to-B bit 2
fault_type = 3'd3;
fault_direction = 1'b0;
fault_bit_a = 4'd2;
#10;

check_result(
device_b_in[2] === 1'bz,
"Open-circuit fault on A-to-B"
);

// Test 5: Bridging fault on A-to-B bits 0 and 1
// A5 = 10100101, so bit 0 = 1 and bit 1 = 0.
// Wired-AND result on both bridged lines = 0.
fault_type = 3'd4;
fault_direction = 1'b0;
fault_bit_a = 4'd0;
fault_bit_b = 4'd1;
#10;

check_result(
device_b_in[0] === 1'b0 &&
device_b_in[1] === 1'b0,
"Bridging fault on A-to-B"
);

// Test 6: Disable fault injection
fault_enable = 1'b0;
#10;

check_result(
device_b_in == 8'hA5 && device_a_in == 8'h5A,
"Normal operation restored after fault disable"
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