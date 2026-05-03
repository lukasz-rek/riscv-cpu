#!/usr/bin/env bash
# scripts/run_sim.sh — run xsim batch, collect waveforms into logs/
set -euo pipefail

TOP="${1:?usage: $0 <top_module> [runtime]}"
RUNTIME="${2:-all}"

# resolve repo root (this script lives in scripts/)
REPO="$(cd "$(dirname "$0")/.." && pwd)"
LOGS="$REPO/logs"
SIMDIR="$REPO/vivado_proj/riscv_core.sim/sim_1/behav/xsim"
VIVADO_SETTINGS="/home/luki/Apps/vivado/2025.2/Vivado/settings64.sh"

mkdir -p "$LOGS"
cd "$REPO"

echo ">> [1/3] launching vivado: top=$TOP runtime=$RUNTIME"
# shellcheck disable=SC1090
source "$VIVADO_SETTINGS"
vivado -mode batch -nojournal -nolog \
    -source "$REPO/scripts/run_sim.tcl" \
    -tclargs "$TOP" "$RUNTIME"

VCD_SRC="$SIMDIR/dump.vcd"
SIMLOG="$SIMDIR/simulate.log"

if [[ ! -f "$VCD_SRC" ]]; then
    echo "!! no VCD at $VCD_SRC — hook probably failed, check $SIMLOG" >&2
    exit 1
fi

VCD_OUT="$LOGS/$TOP.vcd"
FST_OUT="$LOGS/$TOP.fst"
LOG_OUT="$LOGS/$TOP.simulate.log"

echo ">> [2/3] copying VCD -> $VCD_OUT"
cp "$VCD_SRC" "$VCD_OUT"
[[ -f "$SIMLOG" ]] && cp "$SIMLOG" "$LOG_OUT"

echo ">> [3/3] converting VCD -> FST"
vcd2fst "$VCD_OUT" "$FST_OUT" >/dev/null

VCD_SZ=$(du -h "$VCD_OUT" | cut -f1)
FST_SZ=$(du -h "$FST_OUT" | cut -f1)
echo ">> done"
echo "   vcd: $VCD_OUT ($VCD_SZ)"
echo "   fst: $FST_OUT ($FST_SZ)"
echo "   open: surfer '$FST_OUT'"
