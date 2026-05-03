#!/usr/bin/env bash
# Usage:
#   ./scripts/run_arch_test.sh <elf_or_dir> [--timeout <Xus>]
set -euo pipefail

TARGET="${1:?usage: $0 <elf_or_dir> [--timeout Xus]}"
TIMEOUT="all"
[[ "${2:-}" == "--timeout" ]] && TIMEOUT="$3"

REPO="$(cd "$(dirname "$0")/.." && pwd)"
VIVADO_SETTINGS="/home/luki/Apps/vivado/2025.2/Vivado/settings64.sh"
NM="llvm-nm"
OBJCOPY="llvm-objcopy"

source "$VIVADO_SETTINGS"

run_one() {
    local ELF="$1"
    local TEST_NAME
    TEST_NAME="$(basename "${ELF%.elf}")"
    local OUT_DIR="$REPO/logs/arch/$TEST_NAME"
    mkdir -p "$OUT_DIR"

    echo "── $TEST_NAME ──"

    # Extract symbols
    local TOHOST SIG_BEGIN SIG_END
    TOHOST=$(   ${NM} "$ELF" | awk '$3=="tohost"          {print $1; exit}')
    SIG_BEGIN=$(${NM} "$ELF" | awk '$3=="begin_signature" {print $1; exit}')
    SIG_END=$(  ${NM} "$ELF" | awk '$3=="end_signature"   {print $1; exit}')

    [[ -z "$TOHOST" || -z "$SIG_BEGIN" || -z "$SIG_END" ]] && {
        echo "!! missing symbols in $ELF, skipping" >&2; return 1
    }
    echo "   tohost=0x$TOHOST  sig=[0x$SIG_BEGIN..0x$SIG_END]"

    # ELF -> hex (same as your Makefile)
    local HEX="$OUT_DIR/$TEST_NAME.hex"
    local BIN="$OUT_DIR/$TEST_NAME.bin"
    ${OBJCOPY} -O binary "$ELF" "$BIN"
    hexdump -v -e '1/4 "%08x\n"' "$BIN" > "$HEX"
    rm "$BIN"

    # Run sim
    local PLUSARGS="+TOHOST=${TOHOST} +SIG_BEGIN=${SIG_BEGIN} +SIG_END=${SIG_END}"
    PLUSARGS+=" +HEX_FILE=${HEX} +OUT_DIR=${OUT_DIR}"

    vivado -mode batch -nojournal -nolog \
        -source "$REPO/scripts/run_arch_sim.tcl" \
        -tclargs "riscv_arch_tb" "$TIMEOUT" "$PLUSARGS"

    # Check result
    local SIG="$OUT_DIR/DUT.signature"
    local REF="${ELF%.elf}.reference_output"
    if [[ -f "$SIG" && -f "$REF" ]]; then
        if diff -q "$SIG" "$REF" >/dev/null 2>&1; then
            echo "   ✓ PASS"
        else
            echo "   ✗ FAIL"
            diff "$REF" "$SIG" | head -10
        fi
    elif [[ ! -f "$SIG" ]]; then
        echo "   !! no signature — timeout or crash"
    fi
}

# Single ELF or directory
if [[ -f "$TARGET" ]]; then
    run_one "$TARGET"
else
    mapfile -t ELFS < <(find "$TARGET" -name '*.elf' | sort)
    echo "Found ${#ELFS[@]} tests in $TARGET"
    PASS=0; FAIL=0
    for elf in "${ELFS[@]}"; do
        if run_one "$elf"; then
            ((PASS++)) || true
        else
            ((FAIL++)) || true
        fi
    done
    echo "══ done: $PASS passed, $FAIL failed ══"
fi
