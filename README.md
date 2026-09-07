# Prebuilt Dependencies

Static prebuilt libraries. All builds are fully static with zero C/C++ runtime DLL dependencies.

## Naming Convention

### Workflow files
```
build-{package}-{version}-{platform}-{compiler}-{compiler_version}.yml
```

### Release tags & Artifact files
```
{package}-{version}-{target_triple}-{compiler}-{compiler_version}-{stdlib}-{lld}.{ext}
```

| Field | Description | Example |
|-------|-------------|---------|
| `package` | Library name | `llvm`, `wasmedge` |
| `version` | Exact version | `23.1.0`, `0.17.1` |
| `target_triple` | LLVM target triple | `x86_64-pc-windows-msvc`, `x86_64-w64-windows-gnu`, `x86_64-linux-linux` |
| `compiler` | Compiler family | `msvc`, `clang`, `mingw`, `emscripten` |
| `compiler_version` | Compiler version | `19.44`, `22.1.3`, `23.1.0`, `3.1.64` |
| `stdlib` | C++ standard library | `mt` (MSVC static CRT), `libcxx`, `static` |
| `lld` | Linker | `lld` |

### Artifact extensions
- `.zip` for Windows (native MSVC)
- `.tar.gz` for Linux, macOS, Emscripten, MinGW cross-compile

## Workflows

| Workflow | Platform | Release Tag |
|----------|----------|-------------|
| `build-llvm-23.1.0-linux-alpine-clang22.yml` | Linux x86_64 (Alpine) | `llvm-23.1.0-x86_64-linux-linux-clang-22.1.3-libcxx-lld` |
| `build-llvm-23.1.0-windows-mingw-llvm23.yml` | Windows x86_64 (MinGW) | `llvm-23.1.0-x86_64-w64-windows-gnu-mingw-23.1.0-libcxx-lld` |
| `build-llvm-23.1.0-windows-msvc-19.44.yml` | Windows x86_64 (MSVC) | `llvm-23.1.0-x86_64-pc-windows-msvc-19.44-mt-lld` |
| `build-llvm-23.1.0-macos-clang-23.1.0.yml` | macOS aarch64 | `llvm-23.1.0-aarch64-apple-macos-clang-23.1.0-libcxx-lld` |
| `build-llvm-23.1.0-emscripten-3.1.64.yml` | Emscripten wasm32 | `llvm-23.1.0-wasm32-unknown-emscripten-emscripten-3.1.64-libcxx-lld` |
| `build-wasmedge-0.17.1-linux-alpine-clang22.yml` | Linux x86_64 (Alpine) | `wasmedge-0.17.1-x86_64-linux-linux-clang-22.1.3-libcxx-lld` |
| `build-wasmedge-0.17.1-windows-mingw-llvm23.yml` | Windows x86_64 (MinGW) | `wasmedge-0.17.1-x86_64-w64-windows-gnu-mingw-23.1.0-libcxx-lld` |
| `build-wasmedge-0.17.1-windows-msvc-19.44.yml` | Windows x86_64 (MSVC) | `wasmedge-0.17.1-x86_64-pc-windows-msvc-19.44-mt-lld` |
| `build-wasmedge-0.17.1-macos-clang-23.1.0.yml` | macOS aarch64 | `wasmedge-0.17.1-aarch64-apple-macos-clang-23.1.0-libcxx-lld` |
| `build-vulkan-loader-1.4.362-windows-mingw-llvm23.yml` | Windows x86_64 (MinGW) | `vulkan-loader-1.4.362-x86_64-w64-windows-gnu-mingw-23.1.0-static` |
| `build-vulkan-loader-1.4.362-linux-alpine-clang22.yml` | Linux x86_64 (Alpine) | `vulkan-loader-1.4.362-x86_64-linux-linux-clang-22.1.3-static` |
| `build-libuv-1.49.2-windows-mingw-llvm23.yml` | Windows x86_64 (MinGW) | `libuv-1.49.2-x86_64-w64-windows-gnu-mingw-23.1.0-static` |
| `build-libuv-1.49.2-linux-alpine-clang22.yml` | Linux x86_64 (Alpine) | `libuv-1.49.2-x86_64-linux-linux-clang-22.1.3-static` |

## Build Strategy

### LLVM
- **Linux (Alpine)**: Clang 22.1.3, `LLVM_ENABLE_LIBCXX=ON`, LLD linker, native musl
- **Windows (MinGW)**: llvm-mingw Clang 23.1.0, `LLVM_ENABLE_LIBCXX=ON`, LLD linker, cross-compile from Linux
- **Windows (MSVC)**: `/MT` static CRT (MSVC 19.44), LLD linker
- **macOS**: Clang 23.1.0, `LLVM_ENABLE_LIBCXX=ON`, LLD linker
- **Emscripten**: Emscripten 3.1.64, `LLVM_TARGETS_TO_BUILD=WebAssembly`

### WasmEdge
- All platforms: `WASMEDGE_BUILD_STATIC_LIB=ON`, `WASMEDGE_BUILD_SHARED_LIB=OFF`
- Links LLVM statically via `WASMEDGE_LINK_LLVM_STATIC=ON`
- No plugins, no tools, no tests

### Vulkan-Loader
- **Windows (MinGW)**: llvm-mingw Clang 23.1.0, MinGW patches applied, static loader (`BUILD_STATIC_LOADER=ON`)
- **Linux (Alpine)**: Clang 22.1.3, native musl, static loader (`BUILD_STATIC_LOADER=ON`)
- No tests, no tools

### libuv
- **Windows (MinGW)**: llvm-mingw Clang 23.1.0, static only (`BUILD_SHARED_LIBS=OFF`)
- **Linux (Alpine)**: Clang 22.1.3, native musl, static only (`LIBUV_BUILD_SHARED=OFF`)
- No tests

## Dependency Chain

```
build-llvm-{version}-{platform}-{compiler}  →  build-wasmedge-{version}-{platform}-{compiler}
```

WasmEdge workflows depend on prebuilt LLVM via `workflow_call` with `llvm_release_tag` input.

## Scripts

| Script | Description |
|--------|-------------|
| `scripts/{workflow_name}.py` | Helper scripts, named to match their corresponding workflow |

### Rules
- Scripts **must** be written in **Python 3** (no Bash, PowerShell, or other languages)
- Script filename must match the workflow it belongs to: `build-{package}-{version}-{platform}-{compiler}-{compiler_version}.py`

## Runner Versions

| Platform | Runner |
|----------|--------|
| Windows (MSVC) | `windows-2025` |
| Windows (MinGW) | `ubuntu-latest` + `container: mstorsjo/llvm-mingw:20260826` |
| Linux (Alpine) | `ubuntu-latest` + `container: alpine:3.24` |
| macOS | `macos-15` |
| Emscripten | `ubuntu-24.04` |

## License

All prebuilt libraries use permissive licenses. **Static linking does NOT cause GPL contamination.** Your application can be closed-source and commercial.

| Library | License | Commercial Use |
|---------|---------|----------------|
| LLVM (libc++, compiler-rt, LLD) | Apache 2.0 with [LLVM Exception](https://llvm.org/docs/DeveloperPolicy.html#legacy) | ✅ |
| WasmEdge | Apache 2.0 | ✅ |
| Vulkan-Loader | Apache 2.0 | ✅ |
| libuv | MIT | ✅ |

### Why static linking is safe

LLVM uses the [Apache License 2.0 with LLVM Exception](https://llvm.org/devlicensing.html). The **LLVM Exception** is an additional clause added by the LLVM project to the Apache 2.0 license — it explicitly grants a patent license and clarifies that linking against LLVM runtime libraries (libc++, compiler-rt) does **not** trigger GPL copyleft requirements. Your application remains closed-source compatible.

> **Reference**: [GNU GPL](https://www.gnu.org/licenses/gpl-3.0.html) — The GPL license itself. The LLVM Exception clause (not part of GPL) specifically addresses GPL concerns when linking LLVM libraries.

### Runtime component breakdown

| Component | License | GPL Risk |
|-----------|---------|----------|
| libc++ | Apache 2.0 + LLVM Exception | None |
| compiler-rt | Apache 2.0 + LLVM Exception | None |
| LLD | Apache 2.0 + LLVM Exception | None |
| MinGW-w64 CRT | Public Domain / BSD | None |
| libuv | MIT | None |
| WasmEdge | Apache 2.0 | None |
| Vulkan-Loader | Apache 2.0 | None |
