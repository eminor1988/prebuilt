#!/usr/bin/env bash
# test/wasmedge/run_test.sh — Self-contained WasmEdge test
#
# Env vars:
#   GIT_COMMIT    — (required) Git SHA for artifact download
#   GITHUB_REPO   — owner/repo (default: eminor1988/prebuilt)
#   ARTIFACT_TAG  — artifact tag (default: linux-alpine-clang22)
#   ARTIFACT_DIR  — download/extract/build dir (default: test/artifacts)
#   BUILD_RUN     — "run" (default) or "link"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="${GITHUB_REPO:-eminor1988/prebuilt}"
TAG="${ARTIFACT_TAG:-linux-alpine-clang22}"
COMMIT="${GIT_COMMIT:-}"
MODE="${BUILD_RUN:-run}"
ARTIFACT_DIR="${ARTIFACT_DIR:-$SCRIPT_DIR/../artifacts}"

if [ -z "$COMMIT" ]; then
    echo "ERROR: GIT_COMMIT is required"
    exit 1
fi

ARTIFACT_NAME="wasmedge-linux-musl-x86_64.tar.gz"
ARTIFACT_URL="https://github.com/${REPO}/releases/download/${COMMIT}-${TAG}/${ARTIFACT_NAME}"
PREFIX="${ARTIFACT_DIR}/wasmedge-prefix"

echo ""
echo "========================================"
echo "  Testing wasmedge"
echo "========================================"

# Download
mkdir -p "$ARTIFACT_DIR"
echo "--- Downloading ${ARTIFACT_NAME} ---"
wget -q --show-progress -O "${ARTIFACT_DIR}/${ARTIFACT_NAME}" "$ARTIFACT_URL"

# Extract
mkdir -p "$PREFIX"
tar xzf "${ARTIFACT_DIR}/${ARTIFACT_NAME}" -C "$PREFIX"

# Build
cmake -B "${ARTIFACT_DIR}/build/wasmedge" -S "$SCRIPT_DIR" \
    -G Ninja \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
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
