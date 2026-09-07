#!/usr/bin/env bash
# test/wasmedge/run_test.sh — Self-contained WasmEdge test
#
# Env vars:
#   GITHUB_REPO   — owner/repo (default: eminor1988/prebuilt)
#   ARTIFACT_DIR  — download/extract/build dir (default: test/artifacts)
#   BUILD_RUN     — "run" (default) or "link"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="${GITHUB_REPO:-eminor1988/prebuilt}"
MODE="${BUILD_RUN:-run}"
ARTIFACT_DIR="${ARTIFACT_DIR:-$SCRIPT_DIR/../artifacts}"

RELEASE_TAG="wasmedge-0.17.1-x86_64-linux-linux-clang-22.1.3-libcxx-lld"
ARTIFACT_NAME="${RELEASE_TAG}.tar.gz"
ARTIFACT_URL="https://github.com/${REPO}/releases/download/${RELEASE_TAG}/${ARTIFACT_NAME}"
PREFIX="${ARTIFACT_DIR}/wasmedge-prefix"

echo ""
echo "========================================"
echo "  Testing wasmedge"
echo "========================================"

# Download
mkdir -p "$ARTIFACT_DIR"
if [ ! -f "${ARTIFACT_DIR}/${ARTIFACT_NAME}" ]; then
    echo "--- Downloading ${ARTIFACT_NAME} ---"
    wget -q -O "${ARTIFACT_DIR}/${ARTIFACT_NAME}" "$ARTIFACT_URL"
else
    echo "--- Using cached ${ARTIFACT_NAME} ---"
fi

# Extract
if [ ! -d "${PREFIX}/lib" ]; then
    mkdir -p "$PREFIX"
    tar xzf "${ARTIFACT_DIR}/${ARTIFACT_NAME}" -C "$PREFIX"
fi

# Build
cmake -B "${ARTIFACT_DIR}/build/wasmedge" -S "$SCRIPT_DIR" \
    -G Ninja \
    -DCMAKE_C_COMPILER=clang-22 \
    -DCMAKE_CXX_COMPILER=clang++-22 \
    -DCMAKE_CXX_FLAGS="-stdlib=libc++" \
    -DCMAKE_LINKER=lld \
    -DCMAKE_BUILD_TYPE=Release \
    -DWASMEDGE_DIR="$PREFIX"

cmake --build "${ARTIFACT_DIR}/build/wasmedge"

# Run
if [ "$MODE" = "run" ]; then
    echo "--- Running test ---"
    cd "$SCRIPT_DIR"
    "${ARTIFACT_DIR}/build/wasmedge/test_wasm"
else
    echo "--- Link check only ---"
fi
