#!/usr/bin/env bash
# run_test.sh — Download prebuilt artifacts and run tests
# Usage: ./run_test.sh [libuv|vulkan|wasmedge|all]
#
# Environment variables:
#   GITHUB_REPO       — owner/repo (default: eminor1988/prebuilt)
#   ARTIFACT_TAG      — artifact tag suffix (default: linux-alpine-clang22)
#   GIT_COMMIT        — git commit SHA for artifact download
#   BUILD_RUN         — set to "run" to execute, "link" for link-only

set -euo pipefail

REPO="${GITHUB_REPO:-eminor1988/prebuilt}"
TAG="${ARTIFACT_TAG:-linux-alpine-clang22}"
COMMIT="${GIT_COMMIT:-}"
MODE="${BUILD_RUN:-run}"
TESTS="${1:-all}"

if [ -z "$COMMIT" ]; then
    echo "ERROR: GIT_COMMIT is required"
    echo "Usage: GIT_COMMIT=<sha> ./run_test.sh [libuv|vulkan|wasmedge|all]"
    exit 1
fi

ARTIFACT_BASE="https://github.com/${REPO}/releases/download/${COMMIT}-${TAG}"
WORKDIR="/workspace"

download_artifact() {
    local name="$1"
    local url="${ARTIFACT_BASE}/${name}"
    echo "--- Downloading ${name} ---"
    wget -q --show-progress -O "${WORKDIR}/${name}" "$url"
}

mkdir -p "${WORKDIR}/build"

# ---------- libuv ----------
test_libuv() {
    echo ""
    echo "========================================"
    echo "  Testing libuv"
    echo "========================================"
    download_artifact "libuv-linux-musl-x86_64.tar.gz"

    mkdir -p "${WORKDIR}/libuv-prefix"
    tar xzf "${WORKDIR}/libuv-linux-musl-x86_64.tar.gz" -C "${WORKDIR}/libuv-prefix"

    cmake -B "${WORKDIR}/build/libuv" -S "${WORKDIR}/test/libuv" \
        -G Ninja \
        -DCMAKE_C_COMPILER=clang \
        -DCMAKE_CXX_COMPILER=clang++ \
        -DCMAKE_BUILD_TYPE=Release \
        -DLIBUV_DIR="${WORKDIR}/libuv-prefix"

    cmake --build "${WORKDIR}/build/libuv"

    if [ "$MODE" = "run" ]; then
        echo "--- Running test ---"
        "${WORKDIR}/build/libuv/test_libuv"
    else
        echo "--- Link check only ---"
    fi
}

# ---------- vulkan ----------
test_vulkan() {
    echo ""
    echo "========================================"
    echo "  Testing vulkan-loader"
    echo "========================================"
    download_artifact "vulkan-loader-linux-musl-x86_64.tar.gz"

    mkdir -p "${WORKDIR}/vulkan-prefix"
    tar xzf "${WORKDIR}/vulkan-loader-linux-musl-x86_64.tar.gz" -C "${WORKDIR}/vulkan-prefix"

    # Vulkan-Headers (for headers)
    if [ ! -d "${WORKDIR}/Vulkan-Headers" ]; then
        git clone --depth 1 --branch v1.4.309 \
            https://github.com/KhronosGroup/Vulkan-Headers.git "${WORKDIR}/Vulkan-Headers"
    fi

    cmake -B "${WORKDIR}/build/vulkan" -S "${WORKDIR}/test/vulkan" \
        -G Ninja \
        -DCMAKE_C_COMPILER=clang \
        -DCMAKE_CXX_COMPILER=clang++ \
        -DCMAKE_BUILD_TYPE=Release \
        -DVULKAN_HEADERS_DIR="${WORKDIR}/Vulkan-Headers" \
        -DVULKAN_LOADER_DIR="${WORKDIR}/vulkan-prefix"

    cmake --build "${WORKDIR}/build/vulkan"

    if [ "$MODE" = "run" ]; then
        echo "--- Running test ---"
        "${WORKDIR}/build/vulkan/test_vulkan"
    else
        echo "--- Link check only ---"
    fi
}

# ---------- wasmedge ----------
test_wasmedge() {
    echo ""
    echo "========================================"
    echo "  Testing wasmedge"
    echo "========================================"
    download_artifact "wasmedge-linux-musl-x86_64.tar.gz"

    mkdir -p "${WORKDIR}/wasmedge-prefix"
    tar xzf "${WORKDIR}/wasmedge-linux-musl-x86_64.tar.gz" -C "${WORKDIR}/wasmedge-prefix"

    cmake -B "${WORKDIR}/build/wasmedge" -S "${WORKDIR}/test/wasmedge" \
        -G Ninja \
        -DCMAKE_C_COMPILER=clang \
        -DCMAKE_CXX_COMPILER=clang++ \
        -DCMAKE_BUILD_TYPE=Release \
        -DWASMEDGE_DIR="${WORKDIR}/wasmedge-prefix"

    cmake --build "${WORKDIR}/build/wasmedge"

    if [ "$MODE" = "run" ]; then
        echo "--- Running test ---"
        cd "${WORKDIR}/test/wasmedge"
        "${WORKDIR}/build/wasmedge/test_wasm"
    else
        echo "--- Link check only ---"
    fi
}

# ---------- dispatch ----------
case "$TESTS" in
    libuv)    test_libuv ;;
    vulkan)   test_vulkan ;;
    wasmedge) test_wasmedge ;;
    all)
        test_libuv
        test_vulkan
        test_wasmedge
        ;;
    *)
        echo "Unknown test: $TESTS"
        echo "Usage: $0 [libuv|vulkan|wasmedge|all]"
        exit 1
        ;;
esac

echo ""
echo "========================================"
echo "  All requested tests completed!"
echo "========================================"
