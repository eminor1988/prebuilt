#!/usr/bin/env python3
"""Patch WasmEdge 0.17.1 cmake files for MSVC static library building."""
import sys, os

def patch_api_cmake(src_dir):
    path = os.path.join(src_dir, "lib", "api", "CMakeLists.txt")
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    # ---- 1a: wasmedge_add_static_lib_component_command ----
    # Insert elseif(MSVC) before the else() in this function
    old_1a = """\
  else()
    list(APPEND CMDS
      COMMAND ${CMAKE_COMMAND} -E make_directory objs/${target}
      COMMAND ${CMAKE_COMMAND} -E chdir objs/${target} ${CMAKE_AR} -x $<TARGET_FILE:${target}>
    )
    set(WASMEDGE_STATIC_LIB_AR_CMDS ${WASMEDGE_STATIC_LIB_AR_CMDS} ${CMDS} PARENT_SCOPE)
  endif()
  set(WASMEDGE_STATIC_LIB_DEPS ${WASMEDGE_STATIC_LIB_DEPS} ${target} PARENT_SCOPE)
endfunction()"""

    new_1a = """\
  elseif(MSVC)
    # MSVC: lib.exe /OUT: merges .lib files directly, no extract needed.
  else()
    list(APPEND CMDS
      COMMAND ${CMAKE_COMMAND} -E make_directory objs/${target}
      COMMAND ${CMAKE_COMMAND} -E chdir objs/${target} ${CMAKE_AR} -x $<TARGET_FILE:${target}>
    )
    set(WASMEDGE_STATIC_LIB_AR_CMDS ${WASMEDGE_STATIC_LIB_AR_CMDS} ${CMDS} PARENT_SCOPE)
  endif()
  set(WASMEDGE_STATIC_LIB_DEPS ${WASMEDGE_STATIC_LIB_DEPS} ${target} PARENT_SCOPE)
endfunction()"""

    assert old_1a in content, "PATCH 1a FAILED: anchor not found in lib/api/CMakeLists.txt"
    content = content.replace(old_1a, new_1a, 1)
    print("  Patch 1a OK: wasmedge_add_static_lib_component_command")

    # ---- 1b: wasmedge_add_libs_component_command ----
    old_1b = """\
  else()
    list(APPEND CMDS
      COMMAND ${CMAKE_COMMAND} -E make_directory objs/${target_name}
      COMMAND ${CMAKE_COMMAND} -E chdir objs/${target_name} ${CMAKE_AR} -x ${target_path}
    )
    set(WASMEDGE_STATIC_LLVM_LIB_AR_CMDS ${WASMEDGE_STATIC_LLVM_LIB_AR_CMDS} ${CMDS} PARENT_SCOPE)
  endif()
endfunction()"""

    new_1b = """\
  elseif(MSVC)
    # MSVC: lib.exe /OUT: merges .lib files directly, no extract needed.
  else()
    list(APPEND CMDS
      COMMAND ${CMAKE_COMMAND} -E make_directory objs/${target_name}
      COMMAND ${CMAKE_COMMAND} -E chdir objs/${target_name} ${CMAKE_AR} -x ${target_path}
    )
    set(WASMEDGE_STATIC_LLVM_LIB_AR_CMDS ${WASMEDGE_STATIC_LLVM_LIB_AR_CMDS} ${CMDS} PARENT_SCOPE)
  endif()
endfunction()"""

    assert old_1b in content, "PATCH 1b FAILED: anchor not found in lib/api/CMakeLists.txt"
    content = content.replace(old_1b, new_1b, 1)
    print("  Patch 1b OK: wasmedge_add_libs_component_command")

    # ---- 1c: add_custom_command + target + install block ----
    old_1c = """\
  if(CMAKE_AR_NAME STREQUAL "libtool")
    add_custom_command(OUTPUT "libwasmedge.a"
      COMMAND ${CMAKE_AR} -static -o libwasmedge.a ${WASMEDGE_STATIC_LIB_LIBTOOL_FILES} $<TARGET_OBJECTS:wasmedgeCAPI>
      WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
      DEPENDS ${WASMEDGE_STATIC_LIB_DEPS} wasmedgeCAPI
    )
  else()
    add_custom_command(OUTPUT "libwasmedge.a"
      ${WASMEDGE_STATIC_LIB_AR_CMDS}
      ${WASMEDGE_STATIC_LLVM_LIB_AR_CMDS}
      COMMAND ${CMAKE_AR} -qcs libwasmedge.a $<TARGET_OBJECTS:wasmedgeCAPI> objs/*/*.o
      COMMAND ${CMAKE_COMMAND} -E remove_directory objs
      WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
      DEPENDS ${WASMEDGE_STATIC_LIB_DEPS} wasmedgeCAPI
    )
  endif()

  add_custom_target(wasmedge_static_target ALL DEPENDS "libwasmedge.a")
  add_library(wasmedge_static STATIC IMPORTED GLOBAL)
  add_dependencies(wasmedge_static wasmedge_static_target)

  set_target_properties(wasmedge_static
    PROPERTIES
    IMPORTED_LOCATION "${CMAKE_CURRENT_BINARY_DIR}/libwasmedge.a"
    INTERFACE_INCLUDE_DIRECTORIES ${PROJECT_BINARY_DIR}/include/api
  )

  install(FILES ${CMAKE_CURRENT_BINARY_DIR}/libwasmedge.a
    DESTINATION ${CMAKE_INSTALL_LIBDIR}
    COMPONENT WasmEdge
  )"""

    new_1c = """\
  if(MSVC)
    # MSVC: merge all .lib files directly with lib.exe /OUT:
    set(_WASMEDGE_ALL_LIBS "")
    foreach(_DEP ${WASMEDGE_STATIC_LIB_DEPS})
      list(APPEND _WASMEDGE_ALL_LIBS "$<TARGET_FILE:${_DEP}>")
    endforeach()
    foreach(_LLVM_LIB ${WASMEDGE_LLVM_LINK_STATIC_COMPONENTS})
      list(APPEND _WASMEDGE_ALL_LIBS "${_LLVM_LIB}")
    endforeach()
    add_custom_command(OUTPUT "wasmedge.lib"
      COMMAND ${CMAKE_AR} /NOLOGO /OUT:wasmedge.lib ${_WASMEDGE_ALL_LIBS} $<TARGET_OBJECTS:wasmedgeCAPI>
      WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
      DEPENDS ${WASMEDGE_STATIC_LIB_DEPS} wasmedgeCAPI
    )
  elseif(CMAKE_AR_NAME STREQUAL "libtool")
    add_custom_command(OUTPUT "libwasmedge.a"
      COMMAND ${CMAKE_AR} -static -o libwasmedge.a ${WASMEDGE_STATIC_LIB_LIBTOOL_FILES} $<TARGET_OBJECTS:wasmedgeCAPI>
      WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
      DEPENDS ${WASMEDGE_STATIC_LIB_DEPS} wasmedgeCAPI
    )
  else()
    add_custom_command(OUTPUT "libwasmedge.a"
      ${WASMEDGE_STATIC_LIB_AR_CMDS}
      ${WASMEDGE_STATIC_LLVM_LIB_AR_CMDS}
      COMMAND ${CMAKE_AR} -qcs libwasmedge.a $<TARGET_OBJECTS:wasmedgeCAPI> objs/*/*.o
      COMMAND ${CMAKE_COMMAND} -E remove_directory objs
      WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
      DEPENDS ${WASMEDGE_STATIC_LIB_DEPS} wasmedgeCAPI
    )
  endif()

  if(MSVC)
    add_custom_target(wasmedge_static_target ALL DEPENDS "wasmedge.lib")
    add_library(wasmedge_static STATIC IMPORTED GLOBAL)
    add_dependencies(wasmedge_static wasmedge_static_target)
    set_target_properties(wasmedge_static
      PROPERTIES
      IMPORTED_LOCATION "${CMAKE_CURRENT_BINARY_DIR}/wasmedge.lib"
      INTERFACE_INCLUDE_DIRECTORIES ${PROJECT_BINARY_DIR}/include/api
    )
    install(FILES ${CMAKE_CURRENT_BINARY_DIR}/wasmedge.lib
      DESTINATION ${CMAKE_INSTALL_LIBDIR}
      COMPONENT WasmEdge
    )
  else()
    add_custom_target(wasmedge_static_target ALL DEPENDS "libwasmedge.a")
    add_library(wasmedge_static STATIC IMPORTED GLOBAL)
    add_dependencies(wasmedge_static wasmedge_static_target)
    set_target_properties(wasmedge_static
      PROPERTIES
      IMPORTED_LOCATION "${CMAKE_CURRENT_BINARY_DIR}/libwasmedge.a"
      INTERFACE_INCLUDE_DIRECTORIES ${PROJECT_BINARY_DIR}/include/api
    )
    install(FILES ${CMAKE_CURRENT_BINARY_DIR}/libwasmedge.a
      DESTINATION ${CMAKE_INSTALL_LIBDIR}
      COMPONENT WasmEdge
    )
  endif()"""

    assert old_1c in content, "PATCH 1c FAILED: anchor not found in lib/api/CMakeLists.txt"
    content = content.replace(old_1c, new_1c, 1)
    print("  Patch 1c OK: add_custom_command + install block")

    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(content)
    print(f"  Wrote {path}")


def patch_helper_cmake(src_dir):
    path = os.path.join(src_dir, "cmake", "Helper.cmake")
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    # ---- 2a: llvm-config flags ----
    old_2a = """\
  execute_process(
    COMMAND ${LLVM_BINARY_DIR}/bin/llvm-config --libs --link-static
    core lto native nativecodegen option passes support orcjit transformutils all-targets
    OUTPUT_VARIABLE WASMEDGE_LLVM_LINK_LIBS_NAME
  )
  string(REPLACE "-l" "" WASMEDGE_LLVM_LINK_LIBS_NAME "${WASMEDGE_LLVM_LINK_LIBS_NAME}")"""

    new_2a = """\
  if(MSVC)
    execute_process(
      COMMAND ${LLVM_BINARY_DIR}/bin/llvm-config --libnames
      core lto native nativecodegen option passes support orcjit transformutils all-targets
      OUTPUT_VARIABLE WASMEDGE_LLVM_LINK_LIBS_NAME
    )
    string(REPLACE ".lib" "" WASMEDGE_LLVM_LINK_LIBS_NAME "${WASMEDGE_LLVM_LINK_LIBS_NAME}")
  else()
    execute_process(
      COMMAND ${LLVM_BINARY_DIR}/bin/llvm-config --libs --link-static
      core lto native nativecodegen option passes support orcjit transformutils all-targets
      OUTPUT_VARIABLE WASMEDGE_LLVM_LINK_LIBS_NAME
    )
    string(REPLACE "-l" "" WASMEDGE_LLVM_LINK_LIBS_NAME "${WASMEDGE_LLVM_LINK_LIBS_NAME}")
  endif()"""

    assert old_2a in content, "PATCH 2a FAILED: anchor not found in cmake/Helper.cmake"
    content = content.replace(old_2a, new_2a, 1)
    print("  Patch 2a OK: llvm-config flags")

    # ---- 2b: LLD + LLVM library names ----
    old_2b = """\
  list(APPEND WASMEDGE_LLVM_LINK_STATIC_COMPONENTS
    ${LLD_LIBRARY_DIR}/liblldELF.a
    ${LLD_LIBRARY_DIR}/liblldCommon.a
  )
  foreach(LIB_NAME IN LISTS WASMEDGE_LLVM_LINK_LIBS_NAME)
    list(APPEND WASMEDGE_LLVM_LINK_STATIC_COMPONENTS
      ${LLVM_LIBRARY_DIR}/lib${LIB_NAME}.a
    )
  endforeach()
  if(LLVM_VERSION_MAJOR LESS_EQUAL 13)
    # For LLVM <= 13
    list(APPEND WASMEDGE_LLVM_LINK_STATIC_COMPONENTS
      ${LLD_LIBRARY_DIR}/liblldCore.a
      ${LLD_LIBRARY_DIR}/liblldDriver.a
      ${LLD_LIBRARY_DIR}/liblldReaderWriter.a
      ${LLD_LIBRARY_DIR}/liblldYAML.a
    )
  else()
    # For LLVM 14
    list(APPEND WASMEDGE_LLVM_LINK_STATIC_COMPONENTS
      ${LLD_LIBRARY_DIR}/liblldMinGW.a
      ${LLD_LIBRARY_DIR}/liblldCOFF.a
      ${LLD_LIBRARY_DIR}/liblldMachO.a
      ${LLD_LIBRARY_DIR}/liblldWasm.a
    )
  endif()"""

    new_2b = """\
  if(MSVC)
    list(APPEND WASMEDGE_LLVM_LINK_STATIC_COMPONENTS
      ${LLD_LIBRARY_DIR}/lldELF.lib
      ${LLD_LIBRARY_DIR}/lldCommon.lib
    )
    foreach(LIB_NAME IN LISTS WASMEDGE_LLVM_LINK_LIBS_NAME)
      list(APPEND WASMEDGE_LLVM_LINK_STATIC_COMPONENTS
        ${LLVM_LIBRARY_DIR}/${LIB_NAME}.lib
      )
    endforeach()
    if(LLVM_VERSION_MAJOR LESS_EQUAL 13)
      list(APPEND WASMEDGE_LLVM_LINK_STATIC_COMPONENTS
        ${LLD_LIBRARY_DIR}/lldCore.lib
        ${LLD_LIBRARY_DIR}/lldDriver.lib
        ${LLD_LIBRARY_DIR}/lldReaderWriter.lib
        ${LLD_LIBRARY_DIR}/lldYAML.lib
      )
    else()
      list(APPEND WASMEDGE_LLVM_LINK_STATIC_COMPONENTS
        ${LLD_LIBRARY_DIR}/lldMinGW.lib
        ${LLD_LIBRARY_DIR}/lldCOFF.lib
        ${LLD_LIBRARY_DIR}/lldMachO.lib
        ${LLD_LIBRARY_DIR}/lldWasm.lib
      )
    endif()
  else()
    list(APPEND WASMEDGE_LLVM_LINK_STATIC_COMPONENTS
      ${LLD_LIBRARY_DIR}/liblldELF.a
      ${LLD_LIBRARY_DIR}/liblldCommon.a
    )
    foreach(LIB_NAME IN LISTS WASMEDGE_LLVM_LINK_LIBS_NAME)
      list(APPEND WASMEDGE_LLVM_LINK_STATIC_COMPONENTS
        ${LLVM_LIBRARY_DIR}/lib${LIB_NAME}.a
      )
    endforeach()
    if(LLVM_VERSION_MAJOR LESS_EQUAL 13)
      list(APPEND WASMEDGE_LLVM_LINK_STATIC_COMPONENTS
        ${LLD_LIBRARY_DIR}/liblldCore.a
        ${LLD_LIBRARY_DIR}/liblldDriver.a
        ${LLD_LIBRARY_DIR}/liblldReaderWriter.a
        ${LLD_LIBRARY_DIR}/liblldYAML.a
      )
    else()
      list(APPEND WASMEDGE_LLVM_LINK_STATIC_COMPONENTS
        ${LLD_LIBRARY_DIR}/liblldMinGW.a
        ${LLD_LIBRARY_DIR}/liblldCOFF.a
        ${LLD_LIBRARY_DIR}/liblldMachO.a
        ${LLD_LIBRARY_DIR}/liblldWasm.a
      )
    endif()
  endif()"""

    assert old_2b in content, "PATCH 2b FAILED: anchor not found in cmake/Helper.cmake"
    content = content.replace(old_2b, new_2b, 1)
    print("  Patch 2b OK: LLD + LLVM library names")

    # ---- 2c: zstd library ----
    old_2c = """\
    if(APPLE OR LLVM_VERSION_MAJOR GREATER_EQUAL 16)
      find_package(zstd REQUIRED)
      get_filename_component(ZSTD_PATH "${zstd_LIBRARY}" DIRECTORY)
      list(APPEND WASMEDGE_LLVM_LINK_STATIC_COMPONENTS
        ${ZSTD_PATH}/libzstd.a
      )
    endif()"""

    new_2c = """\
    if(APPLE OR LLVM_VERSION_MAJOR GREATER_EQUAL 16 OR MSVC)
      find_package(zstd REQUIRED)
      get_filename_component(ZSTD_PATH "${zstd_LIBRARY}" DIRECTORY)
      if(MSVC)
        list(APPEND WASMEDGE_LLVM_LINK_STATIC_COMPONENTS
          ${ZSTD_PATH}/zstd.lib
        )
      else()
        list(APPEND WASMEDGE_LLVM_LINK_STATIC_COMPONENTS
          ${ZSTD_PATH}/libzstd.a
        )
      endif()
    endif()"""

    assert old_2c in content, "PATCH 2c FAILED: anchor not found in cmake/Helper.cmake"
    content = content.replace(old_2c, new_2c, 1)
    print("  Patch 2c OK: zstd library")

    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(content)
    print(f"  Wrote {path}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <WasmEdge-source-dir>")
        sys.exit(1)

    src = sys.argv[1]
    print(f"Patching WasmEdge source in: {src}")
    print("Patching lib/api/CMakeLists.txt...")
    patch_api_cmake(src)
    print("Patching cmake/Helper.cmake...")
    patch_helper_cmake(src)
    print("=== All MSVC patches applied successfully ===")
