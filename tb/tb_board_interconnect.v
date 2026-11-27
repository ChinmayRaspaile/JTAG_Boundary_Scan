`timescale 1ns/1ps


module tb_board_interconnect;

reg [7:0] device_a_out;
reg [7:0] device_b_out;

wire [7:0] device_a_in;
wire [7:0] device_b_in;

integer passed;
integer failed;

board_interconnect #(
.WIDTH(8)
) uut (
.device_a_out(device_a_out),
.device_b_out(device_b_out),
.device_a_in(device_a_in),
.device_b_in(device_b_in)
);

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

initial begin

$dumpfile("waves/board_interconnect.vcd");
$dumpvars(0, tb_board_interconnect);

passed = 0;
failed = 0;

device_a_out = 8'h00;
device_b_out = 8'h00;

$display("");
$display("======================================");
$display("    PCB INTERCONNECT TEST");
$display("======================================");

#10;

// Test 1: Device A -> Device B
device_a_out = 8'hA5;
#10;

$display("");
$display("---------- A TO B TEST ----------");
$display("Device A output : %02h", device_a_out);
$display("Device B input  : %02h", device_b_in);

check(device_b_in == 8'hA5,
"Device A data reaches Device B");

// Test 2: Device B -> Device A
device_b_out = 8'h5A;
#10;

$display("");
$display("---------- B TO A TEST ----------");
$display("Device B output : %02h", device_b_out);
$display("Device A input  : %02h", device_a_in);

check(device_a_in == 8'h5A,
"Device B data reaches Device A");

// Test 3: Different simultaneous patterns
device_a_out = 8'hC3;
device_b_out = 8'h3C;
#10;

$display("");
$display("---------- SIMULTANEOUS TEST ----------");

$display("Device A output : %02h", device_a_out);
$display("Device B input  : %02h", device_b_in);

$display("Device B output : %02h", device_b_out);
$display("Device A input  : %02h", device_a_in);

check(device_b_in == 8'hC3,
"A to B simultaneous transfer");

check(device_a_in == 8'h3C,
"B to A simultaneous transfer");

// Test 4: All ones
device_a_out = 8'hFF;
device_b_out = 8'hFF;
#10;

check(device_a_in == 8'hFF &&
device_b_in == 8'hFF,
"All-ones interconnect test");

// Test 5: All zeros
device_a_out = 8'h00;
device_b_out = 8'h00;
#10;

check(device_a_in == 8'h00 &&
device_b_in == 8'h00,
"All-zeros interconnect test");

// Test summary
$display("");
$display("======================================");
$display("           TEST SUMMARY");
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