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
| `target_triple` | LLVM target triple | `x86_64-pc-windows-msvc`, `x86_64-linux-linux` |
| `compiler` | Compiler family | `msvc`, `clang`, `emscripten` |
| `compiler_version` | Compiler version | `19.44`, `23.1.0`, `3.1.64` |
| `stdlib` | C++ standard library | `mt` (MSVC static CRT), `libcxx` |
| `lld` | Linker | `lld` |

### Artifact extensions
- `.zip` for Windows
- `.tar.gz` for Linux, macOS, Emscripten

## Workflows

| Workflow | Platform | Release Tag |
|----------|----------|-------------|
| `build-llvm-23.1.0-windows-msvc-19.44.yml` | Windows x86_64 | `llvm-23.1.0-x86_64-pc-windows-msvc-19.44-mt-lld` |
| `build-llvm-23.1.0-linux-clang-23.1.0.yml` | Linux x86_64 | `llvm-23.1.0-x86_64-linux-linux-clang-23.1.0-libcxx-lld` |
| `build-llvm-23.1.0-macos-clang-23.1.0.yml` | macOS aarch64 | `llvm-23.1.0-aarch64-apple-macos-clang-23.1.0-libcxx-lld` |
| `build-llvm-23.1.0-emscripten-3.1.64.yml` | Emscripten wasm32 | `llvm-23.1.0-wasm32-unknown-emscripten-emscripten-3.1.64-libcxx-lld` |
| `build-wasmedge-0.17.1-windows-msvc-19.44.yml` | Windows x86_64 | `wasmedge-0.17.1-x86_64-pc-windows-msvc-19.44-mt-lld` |
| `build-wasmedge-0.17.1-linux-clang-23.1.0.yml` | Linux x86_64 | `wasmedge-0.17.1-x86_64-linux-linux-clang-23.1.0-libcxx-lld` |
| `build-wasmedge-0.17.1-macos-clang-23.1.0.yml` | macOS aarch64 | `wasmedge-0.17.1-aarch64-apple-macos-clang-23.1.0-libcxx-lld` |

## Build Strategy

### LLVM
- **Windows**: `/MT` static CRT (MSVC 19.44), LLD linker
- **Linux**: Clang 23.1.0, `LLVM_ENABLE_LIBCXX=ON`, LLD linker
- **macOS**: Clang 23.1.0, `LLVM_ENABLE_LIBCXX=ON`, LLD linker
- **Emscripten**: Emscripten 3.1.64, `LLVM_TARGETS_TO_BUILD=WebAssembly`

### WasmEdge
- All platforms: `WASMEDGE_BUILD_STATIC_LIB=ON`, `WASMEDGE_BUILD_SHARED_LIB=OFF`
- Links LLVM statically via `WASMEDGE_LINK_LLVM_STATIC=ON`
- No plugins, no tools, no tests

## Dependency Chain

```
build-llvm-{version}-{platform}-{compiler}  →  build-wasmedge-{version}-{platform}-{compiler}
```

WasmEdge workflows depend on prebuilt LLVM via `workflow_call` with `llvm_release_tag` input.

## Runner Versions (Fixed)

| Platform | Runner |
|----------|--------|
| Windows | `windows-2025` |
| Linux | `ubuntu-24.04` |
| macOS | `macos-15` |

## License

All prebuilt libraries use permissive licenses:
- LLVM: Apache 2.0 with LLVM Exception
- WasmEdge: Apache 2.0
- libuv: MIT
