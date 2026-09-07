#!/usr/bin/env bash
# test/vulkan/run_test.sh — Self-contained Vulkan-Loader test
#
# Env vars:
#   GIT_COMMIT    — (required) Git SHA for artifact download
#   GITHUB_REPO   — owner/repo (default: eminor1988/prebuilt)
#   ARTIFACT_DIR  — download/extract/build dir (default: test/artifacts)
#   BUILD_RUN     — "run" (default) or "link"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="${GITHUB_REPO:-eminor1988/prebuilt}"
MODE="${BUILD_RUN:-run}"
ARTIFACT_DIR="${ARTIFACT_DIR:-$SCRIPT_DIR/../artifacts}"

RELEASE_TAG="vulkan-loader-v1.4.362-x86_64-linux-linux-clang-22.1.3-static-lld"
ARTIFACT_NAME="${RELEASE_TAG}.tar.gz"
ARTIFACT_URL="https://github.com/${REPO}/releases/download/${RELEASE_TAG}/${ARTIFACT_NAME}"
PREFIX="${ARTIFACT_DIR}/vulkan-prefix"

echo ""
echo "========================================"
echo "  Testing vulkan-loader"
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

# Vulkan-Headers (for compile-time headers only, not linked)
HEADERS_DIR="${ARTIFACT_DIR}/Vulkan-Headers"
if [ ! -d "$HEADERS_DIR" ]; then
    echo "--- Cloning Vulkan-Headers ---"
    git clone --depth 1 --branch v1.4.309 \
        https://github.com/KhronosGroup/Vulkan-Headers.git "$HEADERS_DIR"
fi

# Build
cmake -B "${ARTIFACT_DIR}/build/vulkan" -S "$SCRIPT_DIR" \
    -G Ninja \
    -DCMAKE_C_COMPILER=clang-22 \
    -DCMAKE_CXX_COMPILER=clang++-22 \
    -DCMAKE_LINKER=lld \
    -DCMAKE_BUILD_TYPE=Release \
    -DVULKAN_HEADERS_DIR="$HEADERS_DIR" \
    -DVULKAN_LOADER_DIR="$PREFIX"

cmake --build "${ARTIFACT_DIR}/build/vulkan"

# Run
if [ "$MODE" = "run" ]; then
    echo "--- Running test ---"
    "${ARTIFACT_DIR}/build/vulkan/test_vulkan"
else
    echo "--- Link check only ---"
fi
