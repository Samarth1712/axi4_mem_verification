#!/usr/bin/env bash
# =============================================================
# run.sh — Xcelium compile + simulate for AXI4 UVM testbench
# Usage:
#   ./run.sh                            → runs regression test
#   ./run.sh axi4_smoke_test            → runs named test
#   ./run.sh all                        → runs all tests in sequence
#   ./run.sh axi4_smoke_test --gui | -g → opens SimVision GUI (single test only)
#   ./run.sh --help | -h                → show this help
# =============================================================
set -e
set -o pipefail

usage() {
    sed -n '2,9p' "$0" | sed 's/^# *//'
    exit 0
}

GUI=0
ARGS=()
for arg in "$@"; do
    case "$arg" in
        --gui|-g) GUI=1 ;;
        --help|-h) usage ;;
        *) ARGS+=("$arg") ;;
    esac
done
TEST=${ARGS[0]:-axi4_regression_test}

if [ "$GUI" = "1" ] && [ "$TEST" = "all" ]; then
    echo "ERROR: --gui can't be combined with 'all' (GUI blocks until closed, regression would hang)."
    exit 1
fi

# UVM_HOME — override per-machine. See README "Machine-specific setup".
UVM_HOME=${UVM_HOME:-/tools/cadence/XCELIUM/tools/methodology/UVM/CDNS-1.2/sv}

if [ ! -f "$UVM_HOME/src/uvm_macros.svh" ]; then
    echo "ERROR: UVM_HOME does not look valid: $UVM_HOME"
    echo "       Expected to find: $UVM_HOME/src/uvm_macros.svh"
    echo "       See README 'Machine-specific setup' for how to locate the correct path."
    exit 1
fi

RTL=../rtl/axi4_sram.sv
INTF=../tb/intf/axi4_if.sv
PKG=../tb/pkg/axi4_pkg.sv
TOP=../tb/top/tb_top.sv

for f in "$RTL" "$INTF" "$PKG" "$TOP"; do
    if [ ! -f "$f" ]; then
        echo "ERROR: expected source file not found: $f"
        echo "       Are you running this from the sim/ directory?"
        exit 1
    fi
done

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

# Returns 0/1 via exit code; caller decides whether to treat as fatal.
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
    local status=${PIPESTATUS[0]}

    if [ "$status" -ne 0 ]; then
        echo "  -> $tname: xrun exited with status $status"
    fi
    return "$status"
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
    declare -A RESULT
    declare -A ERR_COUNT

    for t in "${TESTS[@]}"; do
        if run_one "$t"; then
            RESULT[$t]="PASS"
        else
            RESULT[$t]="TOOL ERROR"
        fi
        ERR_COUNT[$t]=$(grep "UVM_ERROR :" "results/$t/run.log" 2>/dev/null | tail -1 | awk -F: '{print $2}' | tr -d ' ')
        ERR_COUNT[$t]=${ERR_COUNT[$t]:-?}
    done

    echo ""
    echo "========================================"
    echo "  Merging coverage databases..."
    echo "========================================"
    imc -exec merge_cov.tcl || echo "  (coverage merge had issues — check above)"

    echo ""
    echo "========================================"
    echo "  REGRESSION SUMMARY"
    echo "========================================"
    printf "  %-25s %-12s %s\n" "TEST" "TOOL STATUS" "UVM_ERROR count"
    for t in "${TESTS[@]}"; do
        printf "  %-25s %-12s %s\n" "$t" "${RESULT[$t]}" "${ERR_COUNT[$t]}"
    done
    echo ""
    echo "  Note: 'TOOL STATUS' reflects xrun's exit code (compile/elab/crash"
    echo "  level). It does NOT guarantee the scoreboard passed — always check"
    echo "  the UVM_ERROR count column too, and the SCOREBOARD SUMMARY in each"
    echo "  results/<test>/run.log for the real verdict."
else
    run_one "$TEST"
fi

echo ""
echo "========================================"
echo "  Done. Logs in results/"
echo "========================================"
