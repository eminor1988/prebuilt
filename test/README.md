# Prebuilt Static Library Test Suite

Manual Docker-based tests to verify prebuilt static libraries link and execute correctly.

## Directory Structure

```
test/
├── libuv/                # libuv event loop + file I/O test
│   ├── CMakeLists.txt
│   └── test_libuv.cpp
├── vulkan/               # Vulkan instance create/destroy test
│   ├── CMakeLists.txt
│   └── test_vulkan.cpp
├── wasmedge/             # WasmEdge WASM execution test
│   ├── CMakeLists.txt
│   ├── test_wasm.cpp
│   └── hello.wasm        # Minimal WASM returning 42
├── Dockerfile.alpine     # Alpine + clang-18 build environment
├── run_test.sh           # Download artifacts + build + test
└── README.md             # This file
```

## Quick Start

```bash
# Build Docker image
docker build -t prebuilt-test -f Dockerfile.alpine .

# Run all tests (Linux musl builds)
docker run --rm \
  -v "$(pwd)/..:/workspace" \
  -e GIT_COMMIT=$(git rev-parse HEAD) \
  prebuilt-test \
  bash run_test.sh all

# Run single test
docker run --rm \
  -v "$(pwd)/..:/workspace" \
  -e GIT_COMMIT=$(git rev-parse HEAD) \
  prebuilt-test \
  bash run_test.sh libuv

# Link-check only (no execution)
docker run --rm \
  -v "$(pwd)/..:/workspace" \
  -e GIT_COMMIT=$(git rev-parse HEAD) \
  -e BUILD_RUN=link \
  prebuilt-test \
  bash run_test.sh all
```

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `GIT_COMMIT` | (required) | Git SHA for artifact download |
| `ARTIFACT_TAG` | `linux-alpine-clang22` | Artifact tag suffix |
| `GITHUB_REPO` | `eminor1988/prebuilt` | GitHub owner/repo |
| `BUILD_RUN` | `run` | `run` = execute, `link` = link-check only |

## What Each Test Does

### libuv
- Writes and reads a file via libuv async I/O
- Verifies event loop runs correctly
- **MinGW**: Also tests Win32 `CreateFileW`/`WriteFile` API

### vulkan
- Enumerates instance extensions
- Creates/destroys `VkInstance`
- Enumerates physical devices
- Tests static linkage with Vulkan-Loader

### wasmedge
- Loads and executes `hello.wasm` (returns `i32` value 42)
- Verifies WasmEdge C API works correctly
