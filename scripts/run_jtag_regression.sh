
#!/bin/bash

set -u

mkdir -p sim waves reports

REPORT="reports/jtag_regression_report.txt"
TOTAL=0
PASSED=0
FAILED=0

echo "========================================" | tee "$REPORT"
echo "       JTAG UNIFIED FAULT REGRESSION" | tee -a "$REPORT"
echo "========================================" | tee -a "$REPORT"
echo "" | tee -a "$REPORT"

run_test() {
    NAME="$1"
    shift

    TOTAL=$((TOTAL + 1))

    echo "----------------------------------------" | tee -a "$REPORT"
    echo "Running: $NAME" | tee -a "$REPORT"
    echo "----------------------------------------" | tee -a "$REPORT"

    if iverilog -g2012 -o "sim/$NAME" "$@"; then
        if vvp "sim/$NAME" > "reports/${NAME}.log" 2>&1; then
            if grep -q "RESULT : ALL TESTS PASSED" "reports/${NAME}.log"; then
                echo "[PASS] $NAME" | tee -a "$REPORT"
                PASSED=$((PASSED + 1))
            else
                echo "[FAIL] $NAME: Testbench reported failures" | tee -a "$REPORT"
                FAILED=$((FAILED + 1))
            fi
        else
            echo "[FAIL] $NAME: Simulation error" | tee -a "$REPORT"
            FAILED=$((FAILED + 1))
        fi
    else
        echo "[FAIL] $NAME: Compilation error" | tee -a "$REPORT"
        FAILED=$((FAILED + 1))
    fi

    echo "" | tee -a "$REPORT"
}

# Common JTAG RTL
RTL="rtl/tap_controller.v
rtl/instruction_register.v
rtl/bypass_register.v
rtl/idcode_register.v
rtl/jtag_register_mux.v
rtl/boundary_scan_cell.v
rtl/boundary_scan_register.v
rtl/jtag_top.v
rtl/jtag_board.v"

# Functional integration tests
run_test jtag_top_test \
    $RTL tb/tb_jtag_top.v

run_test jtag_board_test \
    $RTL rtl/board_interconnect.v tb/tb_jtag_board.v

run_test jtag_board_extest_test \
    $RTL rtl/board_interconnect.v rtl/jtag_board_extest.v \
    tb/tb_jtag_board_extest.v

# Fault injection RTL
FAULT_RTL="$RTL
rtl/board_interconnect_fault.v
rtl/jtag_board_extest_fault.v"

# Fault detection tests
run_test jtag_extest_fault_test \
    $FAULT_RTL tb/tb_jtag_board_extest_fault.v

run_test jtag_stuck_at_sweep \
    $FAULT_RTL tb/tb_jtag_fault_pattern_sweep.v

run_test jtag_bridging_sweep \
    $FAULT_RTL tb/tb_jtag_bridging_fault_sweep.v

run_test jtag_open_circuit_sweep \
    $FAULT_RTL tb/tb_jtag_open_circuit_sweep.v

# Extract numerical fault metrics from simulation logs
extract_metric() {
    FILE="$1"
    PATTERN="$2"

    awk -F: -v pattern="$PATTERN" '
        tolower($1) ~ pattern {
            gsub(/^[ \t]+|[ \t]+$/, "", $2)
            if ($2 ~ /^[0-9]+/) {
                print $2
                exit
            }
        }
    ' "$FILE"
}

echo "========================================" | tee -a "$REPORT"
echo "       COMBINED FAULT COVERAGE" | tee -a "$REPORT"
echo "========================================" | tee -a "$REPORT"

STUCK_LOG="reports/jtag_stuck_at_sweep.log"
BRIDGE_LOG="reports/jtag_bridging_sweep.log"
OPEN_LOG="reports/jtag_open_circuit_sweep.log"

STUCK_TOTAL=$(extract_metric "$STUCK_LOG" "total.*(fault|case|pattern)")
STUCK_DETECTED=$(extract_metric "$STUCK_LOG" "detected faults")

BRIDGE_TOTAL=$(extract_metric "$BRIDGE_LOG" "total.*(fault|case|pattern)")
BRIDGE_DETECTED=$(extract_metric "$BRIDGE_LOG" "detected faults")

OPEN_TOTAL=$(extract_metric "$OPEN_LOG" "total.*(fault|case|pattern)")
OPEN_DETECTED=$(extract_metric "$OPEN_LOG" "detected faults")

METRICS_VALID=1

if [ -z "$STUCK_TOTAL" ] || [ -z "$STUCK_DETECTED" ] ||
   [ -z "$BRIDGE_TOTAL" ] || [ -z "$BRIDGE_DETECTED" ] ||
   [ -z "$OPEN_TOTAL" ] || [ -z "$OPEN_DETECTED" ]; then

    echo "[ERROR] Could not extract all fault metrics from simulation logs." | tee -a "$REPORT"
    METRICS_VALID=0
    FAILED=$((FAILED + 1))
else
    TOTAL_FAULTS=$((STUCK_TOTAL + BRIDGE_TOTAL + OPEN_TOTAL))
    DETECTED_FAULTS=$((STUCK_DETECTED + BRIDGE_DETECTED + OPEN_DETECTED))
    UNDETECTED_FAULTS=$((TOTAL_FAULTS - DETECTED_FAULTS))

    if [ "$TOTAL_FAULTS" -gt 0 ]; then
        COVERAGE=$((DETECTED_FAULTS * 100 / TOTAL_FAULTS))
    else
        COVERAGE=0
    fi

    echo "Fault category       Total    Detected" | tee -a "$REPORT"
    echo "----------------------------------------" | tee -a "$REPORT"
    printf "Stuck-at faults      %-8s %s\n" "$STUCK_TOTAL" "$STUCK_DETECTED" | tee -a "$REPORT"
    printf "Bridging faults      %-8s %s\n" "$BRIDGE_TOTAL" "$BRIDGE_DETECTED" | tee -a "$REPORT"
    printf "Open-circuit faults  %-8s %s\n" "$OPEN_TOTAL" "$OPEN_DETECTED" | tee -a "$REPORT"

    echo "----------------------------------------" | tee -a "$REPORT"
    echo "Total fault cases    : $TOTAL_FAULTS" | tee -a "$REPORT"
    echo "Detected faults      : $DETECTED_FAULTS" | tee -a "$REPORT"
    echo "Undetected faults    : $UNDETECTED_FAULTS" | tee -a "$REPORT"
    echo "Combined coverage    : $COVERAGE%" | tee -a "$REPORT"

    if [ "$UNDETECTED_FAULTS" -ne 0 ]; then
        FAILED=$((FAILED + 1))
        echo "[WARNING] Some simulated faults were not detected." | tee -a "$REPORT"
    fi
fi

echo "" | tee -a "$REPORT"

# Final regression summary
echo "========================================" | tee -a "$REPORT"
echo "         FINAL REGRESSION SUMMARY" | tee -a "$REPORT"
echo "========================================" | tee -a "$REPORT"
echo "Total testbenches : $TOTAL" | tee -a "$REPORT"
echo "Passed            : $PASSED" | tee -a "$REPORT"
echo "Failed            : $FAILED" | tee -a "$REPORT"

if [ "$FAILED" -eq 0 ] && [ "$METRICS_VALID" -eq 1 ]; then
    echo "RESULT : ALL TESTS PASSED" | tee -a "$REPORT"
else
    echo "RESULT : REGRESSION FAILED" | tee -a "$REPORT"
fi

echo ""
echo "Detailed logs: reports/"
echo "Summary report: $REPORT"

if [ "$FAILED" -ne 0 ]; then
    exit 1
fi

