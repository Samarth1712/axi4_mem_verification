#!/usr/bin/env bash
# =============================================================
# run.sh — Xcelium compile + simulate for AXI4 UVM testbench
# Usage:
#   ./run.sh                        → runs regression test
#   ./run.sh axi4_smoke_test        → runs named test
#   ./run.sh all                    → runs all tests in sequence
# =============================================================

set -e

TEST=${1:-axi4_regression_test}

# -----------------------------------------------------------
# Paths — edit UVM_HOME if needed for your installation
# -----------------------------------------------------------
UVM_HOME=${UVM_HOME:-/tools/cadence/XCELIUM/tools/methodology/UVM/CDNS-1.2/sv}
RTL=../../rtl/axi4_sram.sv
INTF=../intf/axi4_if.sv
PKG=../pkg/axi4_pkg.sv
TOP=../top/tb_top.sv

COMPILE_ARGS=(
    -sv
    -uvm
    -uvmhome "$UVM_HOME"
    -access +rwc
    -define UVM_NO_DEPRECATED
    -log compile.log
    "$RTL"
    "$INTF"
    "$PKG"
    "$TOP"
)

SIM_ARGS=(
    -uvm
    -uvmhome "$UVM_HOME"
    -input run.tcl
    -log sim.log
)

# -----------------------------------------------------------
# Helper: run one test
# -----------------------------------------------------------
run_one() {
    local tname=$1
    echo ""
    echo "========================================"
    echo "  RUNNING: $tname"
    echo "========================================"
    mkdir -p "results/$tname"
    xrun "${COMPILE_ARGS[@]}" \
         "${SIM_ARGS[@]}" \
         -coverage all \
         -covdb "results/$tname/cov.db" \
         +UVM_TESTNAME="$tname" \
         +UVM_VERBOSITY=UVM_MEDIUM 2>&1 | tee "results/$tname/run.log"
}

# -----------------------------------------------------------
# Run
# -----------------------------------------------------------
mkdir -p results

if [ "$TEST" = "all" ]; then
    TESTS=(
        axi4_smoke_test
        axi4_integrity_test
        axi4_boundary_test
        axi4_max_burst_test
        axi4_strobe_test
        axi4_bb_test
        axi4_rand_test
        axi4_regression_test
    )
    for t in "${TESTS[@]}"; do
        run_one "$t"
    done

    # Merge coverage databases
    echo ""
    echo "========================================"
    echo "  Merging coverage databases..."
    echo "========================================"
    imc -exec merge_cov.tcl

else
    run_one "$TEST"
fi

echo ""
echo "========================================"
echo "  Done. Logs in results/"
echo "========================================"
