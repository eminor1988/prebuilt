#!/usr/bin/env bash
# test/vulkan/run_test.sh — Self-contained Vulkan-Loader test
#
# Env vars:
#   GIT_COMMIT    — (required) Git SHA for artifact download
#   GITHUB_REPO   — owner/repo (default: eminor1988/prebuilt)
#   ARTIFACT_TAG  — artifact tag (default: linux-alpine-clang22)
#   BUILD_RUN     — "run" (default) or "link"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="${GITHUB_REPO:-eminor1988/prebuilt}"
TAG="${ARTIFACT_TAG:-linux-alpine-clang22}"
COMMIT="${GIT_COMMIT:-}"
MODE="${BUILD_RUN:-run}"
WORKDIR="${WORKDIR:-/workspace}"

if [ -z "$COMMIT" ]; then
    echo "ERROR: GIT_COMMIT is required"
    exit 1
fi

ARTIFACT_NAME="vulkan-loader-linux-musl-x86_64.tar.gz"
ARTIFACT_URL="https://github.com/${REPO}/releases/download/${COMMIT}-${TAG}/${ARTIFACT_NAME}"
PREFIX="${WORKDIR}/vulkan-prefix"

echo ""
echo "========================================"
echo "  Testing vulkan-loader"
echo "========================================"

# Download
echo "--- Downloading ${ARTIFACT_NAME} ---"
wget -q --show-progress -O "${WORKDIR}/${ARTIFACT_NAME}" "$ARTIFACT_URL"

# Extract
mkdir -p "$PREFIX"
tar xzf "${WORKDIR}/${ARTIFACT_NAME}" -C "$PREFIX"

# Vulkan-Headers (for compile-time headers only, not linked)
HEADERS_DIR="${WORKDIR}/Vulkan-Headers"
if [ ! -d "$HEADERS_DIR" ]; then
    echo "--- Cloning Vulkan-Headers ---"
    git clone --depth 1 --branch v1.4.309 \
        https://github.com/KhronosGroup/Vulkan-Headers.git "$HEADERS_DIR"
fi

# Build
cmake -B "${WORKDIR}/build/vulkan" -S "$SCRIPT_DIR" \
    -G Ninja \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_BUILD_TYPE=Release \
    -DVULKAN_HEADERS_DIR="$HEADERS_DIR" \
    -DVULKAN_LOADER_DIR="$PREFIX"

cmake --build "${WORKDIR}/build/vulkan"

# Run
if [ "$MODE" = "run" ]; then
    echo "--- Running test ---"
    "${WORKDIR}/build/vulkan/test_vulkan"
else
    echo "--- Link check only ---"
fi
