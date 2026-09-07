#!/usr/bin/env bash
# test/run_test.sh — Dispatcher for prebuilt static library tests
# Usage: ./run_test.sh [libuv|vulkan|wasmedge|all]
#
# Each subdirectory has its own self-contained run_test.sh.
# Adding a new test: just drop a new directory with run_test.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TESTS="${1:-all}"

# Available tests (directories containing run_test.sh)
AVAILABLE_TESTS=$(find "$SCRIPT_DIR" -mindepth 2 -maxdepth 2 -name "run_test.sh" -printf "%h\n" | sort | xargs -I{} basename {})

run_test() {
    local name="$1"
    local script="${SCRIPT_DIR}/${name}/run_test.sh"
    if [ ! -f "$script" ]; then
        echo "ERROR: test '${name}' not found (no run_test.sh in ${SCRIPT_DIR}/${name}/)"
        return 1
    fi
    echo ""
    echo ">>> Running test: ${name}"
    bash "$script"
}

case "$TESTS" in
    all)
        for t in $AVAILABLE_TESTS; do
            run_test "$t"
        done
        ;;
    *)
        run_test "$TESTS"
        ;;
esac

echo ""
echo "========================================"
echo "  All requested tests completed!"
echo "========================================"
