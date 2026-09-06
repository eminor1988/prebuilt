# patch-wasmedge-msvc.ps1
# Patches WasmEdge 0.17.1 cmake files for MSVC static library building.
# On MSVC, `ar -x` / `ar -qcs` don't work; use `lib.exe /OUT:` to merge directly.
# Library naming: .a -> .lib on MSVC.

param(
  [Parameter(Mandatory)]
  [string]$SourceDir
)

$ErrorActionPreference = "Stop"

# ============================================================
# Patch 1: lib/api/CMakeLists.txt
# ============================================================
$file1 = Join-Path $SourceDir "lib\api\CMakeLists.txt"
$c = (Get-Content $file1 -Raw) -replace "`r`n", "`n"

# --- 1a: wasmedge_add_static_lib_component_command ---
# Insert elseif(MSVC) before the else() branch
$old1a = @'
  else()
    list(APPEND CMDS
      COMMAND ${CMAKE_COMMAND} -E make_directory objs/${target}
      COMMAND ${CMAKE_COMMAND} -E chdir objs/${target} ${CMAKE_AR} -x $<TARGET_FILE:${target}>
    )
    set(WASMEDGE_STATIC_LIB_AR_CMDS ${WASMEDGE_STATIC_LIB_AR_CMDS} ${CMDS} PARENT_SCOPE)
  endif()
  set(WASMEDGE_STATIC_LIB_DEPS ${WASMEDGE_STATIC_LIB_DEPS} ${target} PARENT_SCOPE)
endfunction()
'@

$new1a = @'
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
endfunction()
'@

$c = $c.Replace($old1a, $new1a)
Write-Host "Patched 1a: wasmedge_add_static_lib_component_command"

# --- 1b: wasmedge_add_libs_component_command ---
# Insert elseif(MSVC) before the else() branch
$old1b = @'
  else()
    list(APPEND CMDS
      COMMAND ${CMAKE_COMMAND} -E make_directory objs/${target_name}
      COMMAND ${CMAKE_COMMAND} -E chdir objs/${target_name} ${CMAKE_AR} -x ${target_path}
    )
    set(WASMEDGE_STATIC_LLVM_LIB_AR_CMDS ${WASMEDGE_STATIC_LLVM_LIB_AR_CMDS} ${CMDS} PARENT_SCOPE)
  endif()
endfunction()
'@

$new1b = @'
  elseif(MSVC)
    # MSVC: lib.exe /OUT: merges .lib files directly, no extract needed.
  else()
    list(APPEND CMDS
      COMMAND ${CMAKE_COMMAND} -E make_directory objs/${target_name}
      COMMAND ${CMAKE_COMMAND} -E chdir objs/${target_name} ${CMAKE_AR} -x ${target_path}
    )
    set(WASMEDGE_STATIC_LLVM_LIB_AR_CMDS ${WASMEDGE_STATIC_LLVM_LIB_AR_CMDS} ${CMDS} PARENT_SCOPE)
  endif()
endfunction()
'@

$c = $c.Replace($old1b, $new1b)
Write-Host "Patched 1b: wasmedge_add_libs_component_command"

# --- 1c: Final add_custom_command + target + install block ---
# Replace the if(CMAKE_AR_NAME)/else/endif + add_custom_target + set_target_properties + install
# with MSVC-aware version
$old1c = @'
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
  )
'@

$new1c = @'
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
  endif()
'@

$c = $c.Replace($old1c, $new1c)
Write-Host "Patched 1c: add_custom_command + install block"

Set-Content $file1 $c -NoNewline
Write-Host "Wrote $file1"

# ============================================================
# Patch 2: cmake/Helper.cmake
# ============================================================
$file2 = Join-Path $SourceDir "cmake\Helper.cmake"
$h = (Get-Content $file2 -Raw) -replace "`r`n", "`n"

# --- 2a: llvm-config flags ---
# On MSVC, --libs --link-static returns full paths; use --libnames instead
$old2a = @'
  execute_process(
    COMMAND ${LLVM_BINARY_DIR}/bin/llvm-config --libs --link-static
    core lto native nativecodegen option passes support orcjit transformutils all-targets
    OUTPUT_VARIABLE WASMEDGE_LLVM_LINK_LIBS_NAME
  )
  string(REPLACE "-l" "" WASMEDGE_LLVM_LINK_LIBS_NAME "${WASMEDGE_LLVM_LINK_LIBS_NAME}")
'@

$new2a = @'
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
  endif()
'@

$h = $h.Replace($old2a, $new2a)
Write-Host "Patched 2a: llvm-config flags"

# --- 2b: LLD + LLVM library names ---
# On MSVC, use .lib names instead of .a
$old2b = @'
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
  endif()
'@

$new2b = @'
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
  endif()
'@

$h = $h.Replace($old2b, $new2b)
Write-Host "Patched 2b: LLD + LLVM library names"

# --- 2c: zstd library ---
# On MSVC, use zstd.lib from find_package path
$old2c = @'
    if(APPLE OR LLVM_VERSION_MAJOR GREATER_EQUAL 16)
      find_package(zstd REQUIRED)
      get_filename_component(ZSTD_PATH "${zstd_LIBRARY}" DIRECTORY)
      list(APPEND WASMEDGE_LLVM_LINK_STATIC_COMPONENTS
        ${ZSTD_PATH}/libzstd.a
      )
    endif()
'@

$new2c = @'
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
    endif()
'@

$h = $h.Replace($old2c, $new2c)
Write-Host "Patched 2c: zstd library"

Set-Content $file2 $h -NoNewline
Write-Host "Wrote $file2"

Write-Host "=== All MSVC patches applied successfully ==="
