#!/usr/bin/env bash
# =============================================================
# run.sh — Xcelium compile + simulate for AXI4 UVM testbench
# Usage:
#   ./run.sh                        → runs regression test
#   ./run.sh axi4_smoke_test        → runs named test
#   ./run.sh all                    → runs all tests in sequence
#   ./run.sh axi4_smoke_test --gui  → opens SimVision GUI (single test only)
# =============================================================
set -e
set -o pipefail

GUI=0
ARGS=()
for arg in "$@"; do
    if [ "$arg" = "--gui" ] || [ "$arg" = "-g" ]; then
        GUI=1
    else
        ARGS+=("$arg")
    fi
done
TEST=${ARGS[0]:-axi4_regression_test}

if [ "$GUI" = "1" ] && [ "$TEST" = "all" ]; then
    echo "ERROR: --gui can't be combined with 'all' (GUI blocks until closed, regression would hang)."
    exit 1
fi

# UVM_HOME — override this per-machine, see README "Machine-specific setup"
UVM_HOME=${UVM_HOME:-/tools/cadence/XCELIUM/tools/methodology/UVM/CDNS-1.2/sv}

RTL=../rtl/axi4_sram.sv
INTF=../tb/intf/axi4_if.sv
PKG=../tb/pkg/axi4_pkg.sv
TOP=../tb/top/tb_top.sv

COMPILE_ARGS=(
    -sv
    -uvm
    -uvmhome "$UVM_HOME"
    -access +rwc
    -define UVM_NO_DEPRECATED
    -incdir ../tb/pkg
    -timescale 1ns/1ps
    "$RTL"
    "$INTF"
    "$PKG"
    "$TOP"
)

if [ "$GUI" = "1" ]; then
    SIM_ARGS=(-gui -input run_gui.tcl)
else
    SIM_ARGS=(-input run.tcl)
fi

run_one() {
    local tname=$1
    echo ""
    echo "========================================"
    echo "  RUNNING: $tname"
    echo "========================================"
    mkdir -p "results/$tname"
    export WAVE_DB="results/$tname/waves"
    xrun "${COMPILE_ARGS[@]}" \
         "${SIM_ARGS[@]}" \
         -coverage all \
         -covdb "results/$tname/cov.db" \
         -log "results/$tname/sim.log" \
         +UVM_TESTNAME="$tname" \
         +UVM_VERBOSITY=UVM_MEDIUM 2>&1 | tee "results/$tname/run.log"
}

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
