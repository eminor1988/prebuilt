#!/usr/bin/env python3
"""Patch Vulkan-Loader for MinGW static build.

Changes:
  - loader/CMakeLists.txt: Replace WIN32 checks with MSVC-specific guards,
    replace APPLE_STATIC_LOADER with BUILD_STATIC_LOADER for static builds.
  - loader/loader.c: Replace _WIN32 checks with LOADER_DYNAMIC_LIB for
    dynamic-only code paths.
  - loader/loader.h: Guard LOADER_PLATFORM_THREAD_ONCE_EXTERN_DEFINITION
    and loader_initialize declaration.
  - loader/loader.rc.in: Use <winres.h> for MinGW, "winres.h" for MSVC.
  - loader/loader_windows.c: Guard DllMain behind LOADER_DYNAMIC_LIB.
  - loader/vk_loader_platform.h: Add pthread.h for MinGW, replace
    APPLE_STATIC_LOADER with BUILD_STATIC_LOADER, replace WIN32 thread
    check with LOADER_DYNAMIC_LIB.
"""
import sys
import os


def patch_cmakelists(src_dir):
    path = os.path.join(src_dir, "loader", "CMakeLists.txt")
    with open(path, "r", encoding="utf-8") as f:
        c = f.read()

    # 1. WIN32 -> WIN32 AND NOT MINGW (OneCore/linker flags)
    c = c.replace(
        "if(WIN32)\n\n    if(ENABLE_WIN10_ONECORE)",
        "if(WIN32 AND NOT MINGW)\n\n    if(ENABLE_WIN10_ONECORE)",
    )

    # 2. WIN32 -> MSVC (RC file handling)
    c = c.replace(
        "if(WIN32)\n    # If BUILD_DLL_VERSIONINFO",
        "if(MSVC)\n    # If BUILD_DLL_VERSIONINFO",
    )

    # 3. Replace APPLE_STATIC_LOADER with BUILD_STATIC_LOADER
    OLD = """\
else()
    if(APPLE)
        option(APPLE_STATIC_LOADER "Build a loader that can be statically linked. Intended for Chromium usage/testing.")
        mark_as_advanced(APPLE_STATIC_LOADER)
    endif()

    if(APPLE_STATIC_LOADER)
        add_library(vulkan STATIC)
        target_compile_definitions(vulkan PRIVATE APPLE_STATIC_LOADER)

        message(WARNING "The APPLE_STATIC_LOADER option has been set. Note that this will only work on MacOS and is not supported "
                "or tested as part of the loader. Use it at your own risk.")
    else()
        add_library(vulkan SHARED)
    endif()"""
    NEW = """\
else()
    add_library(vulkan STATIC)
    target_compile_definitions(vulkan PRIVATE BUILD_STATIC_LOADER)"""
    assert OLD in c, "PATCH FAILED: APPLE_STATIC_LOADER block not found in loader/CMakeLists.txt"
    c = c.replace(OLD, NEW, 1)

    # 4. APPLE_STATIC_LOADER -> BUILD_STATIC_LOADER (condition)
    c = c.replace('if (APPLE_STATIC_LOADER)', 'if (BUILD_STATIC_LOADER)')

    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(c)
    print(f"  Patched {path}")


def patch_loader_c(src_dir):
    path = os.path.join(src_dir, "loader", "loader.c")
    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    new_lines = []
    i = 0
    while i < len(lines):
        line = lines[i]
        if "#if defined(_WIN32)" in line:
            context = "".join(lines[max(0, i - 2) : min(len(lines), i + 5)])
            if "dirent" in context or "opendir" in context or "closedir" in context:
                new_lines.append(line)
            else:
                new_lines.append(line.replace("#if defined(_WIN32)", "#if defined(LOADER_DYNAMIC_LIB)"))
        else:
            new_lines.append(line)
        i += 1

    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.writelines(new_lines)
    print(f"  Patched {path}")


def patch_loader_h(src_dir):
    path = os.path.join(src_dir, "loader", "loader.h")
    with open(path, "r", encoding="utf-8") as f:
        c = f.read()

    c = c.replace(
        "LOADER_PLATFORM_THREAD_ONCE_EXTERN_DEFINITION(once_init)",
        "#if defined(_WIN32) && !defined(LOADER_DYNAMIC_LIB)\nLOADER_PLATFORM_THREAD_ONCE_EXTERN_DEFINITION(once_init)\n#endif",
    )
    c = c.replace(
        "#if defined(_WIN32)\nBOOL __stdcall loader_initialize",
        "#if defined(LOADER_DYNAMIC_LIB)\nBOOL __stdcall loader_initialize",
    )

    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(c)
    print(f"  Patched {path}")


def patch_loader_rc_in(src_dir):
    path = os.path.join(src_dir, "loader", "loader.rc.in")
    with open(path, "r", encoding="utf-8") as f:
        c = f.read()

    c = c.replace(
        '#include "winres.h"',
        '#ifdef __MINGW64__\n#include <winres.h>\n#else // MSVC\n#include "winres.h"\n#endif',
    )

    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(c)
    print(f"  Patched {path}")


def patch_loader_windows_c(src_dir):
    path = os.path.join(src_dir, "loader", "loader_windows.c")
    with open(path, "r", encoding="utf-8") as f:
        c = f.read()

    c = c.replace(
        "BOOL WINAPI DllMain(HINSTANCE hinstance, DWORD reason, LPVOID reserved)",
        "#if defined(LOADER_DYNAMIC_LIB)\nBOOL WINAPI DllMain(HINSTANCE hinstance, DWORD reason, LPVOID reserved)",
    )
    c = c.replace(
        "    return TRUE;\n}\n\nVkResult windows_add_json_entry",
        "    return TRUE;\n}\n#endif\n\nVkResult windows_add_json_entry",
    )

    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(c)
    print(f"  Patched {path}")


def patch_vk_loader_platform_h(src_dir):
    path = os.path.join(src_dir, "loader", "vk_loader_platform.h")
    with open(path, "r", encoding="utf-8") as f:
        c = f.read()

    c = c.replace("#include <direct.h>", "#include <direct.h>\n#include <pthread.h> // for mingw")
    c = c.replace(
        '#if defined(APPLE_STATIC_LOADER) && !defined(__APPLE__)\n#error "APPLE_STATIC_LOADER can only be defined on Apple platforms!"\n#endif\n\n#if defined(APPLE_STATIC_LOADER)',
        "#if defined(BUILD_STATIC_LOADER)",
    )
    c = c.replace("APPLE_STATIC_LOADER", "BUILD_STATIC_LOADER")
    c = c.replace("#elif defined(WIN32)", "#elif defined(LOADER_DYNAMIC_LIB)")

    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(c)
    print(f"  Patched {path}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <Vulkan-Loader-source-dir>")
        sys.exit(1)

    src = sys.argv[1]
    print(f"Patching Vulkan-Loader source in: {src}")
    print("Patching loader/CMakeLists.txt...")
    patch_cmakelists(src)
    print("Patching loader/loader.c...")
    patch_loader_c(src)
    print("Patching loader/loader.h...")
    patch_loader_h(src)
    print("Patching loader/loader.rc.in...")
    patch_loader_rc_in(src)
    print("Patching loader/loader_windows.c...")
    patch_loader_windows_c(src)
    print("Patching loader/vk_loader_platform.h...")
    patch_vk_loader_platform_h(src)
    print("=== All MinGW patches applied successfully ===")
