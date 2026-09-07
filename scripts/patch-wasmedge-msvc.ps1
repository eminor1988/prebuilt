# patch-wasmedge-msvc.ps1
# Patches WasmEdge 0.17.1 cmake files for MSVC static library building.
# Uses line-by-line processing for reliability across different line endings.

param(
  [Parameter(Mandatory)]
  [string]$SourceDir
)

$ErrorActionPreference = "Stop"

function Patch-File {
  param([string]$FilePath, [scriptblock]$PatchFunc)
  $lines = Get-Content $FilePath
  $lines = & $PatchFunc $lines
  Set-Content $FilePath ($lines -join "`n") -NoNewline
  Write-Host "Patched $FilePath"
}

# ============================================================
# Patch 1: lib/api/CMakeLists.txt
# ============================================================
$file1 = Join-Path $SourceDir "lib\api\CMakeLists.txt"

Patch-File -FilePath $file1 -PatchFunc {
  param([string[]]$lines)
  $result = @()
  $i = 0
  while ($i -lt $lines.Count) {
    $line = $lines[$i]
    $nextLine = if ($i + 1 -lt $lines.Count) { $lines[$i + 1] } else { "" }

    # --- Patch 1a: wasmedge_add_static_lib_component_command ---
    # Match the else() after endif() in the first function (before "set(WASMEDGE_STATIC_LIB_DEPS")
    # The pattern: "  else()" followed by "    list(APPEND CMDS" with "chdir objs/${target}"
    if ($line.Trim() -eq "else()" -and $nextLine.Trim().StartsWith("list(APPEND CMDS")) {
      # Check if this is in wasmedge_add_static_lib_component_command by looking for ${target} (not ${target_name})
      $lookAhead = ($i + 2 .. [Math]::Min($i + 5, $lines.Count - 1)) | ForEach-Object { $lines[$_] }
      $isFunc1 = ($lookAhead -join "`n") -match 'chdir objs/\$\{target\}'
      $isFunc2 = ($lookAhead -join "`n") -match 'chdir objs/\$\{target_name\}'

      if ($isFunc1 -and -not $isFunc2) {
        $result += "  elseif(MSVC)"
        $result += "    # MSVC: lib.exe /OUT: merges .lib files directly, no extract needed."
        Write-Host "  Inserted elseif(MSVC) in wasmedge_add_static_lib_component_command"
      }
    }

    # --- Patch 1c: Final add_custom_command block ---
    # Replace "if(CMAKE_AR_NAME STREQUAL" with "if(MSVC) ... elseif(CMAKE_AR_NAME STREQUAL"
    if ($line.Trim() -eq 'if(CMAKE_AR_NAME STREQUAL "libtool")') {
      $result += "  if(MSVC)"
      $result += "    # MSVC: merge all .lib files directly with lib.exe /OUT:"
      $result += "    set(_WASMEDGE_ALL_LIBS `"")"
      $result += "    foreach(_DEP `${WASMEDGE_STATIC_LIB_DEPS})"
      $result += "      list(APPEND _WASMEDGE_ALL_LIBS `"`$<TARGET_FILE: `${_DEP}>`")"
      $result += "    endforeach()"
      $result += "    foreach(_LLVM_LIB `${WASMEDGE_LLVM_LINK_STATIC_COMPONENTS})"
      $result += "      list(APPEND _WASMEDGE_ALL_LIBS `"`${_LLVM_LIB}`")"
      $result += "    endforeach()"
      $result += "    add_custom_command(OUTPUT `"wasmedge.lib`""
      $result += "      COMMAND `${CMAKE_AR} /NOLOGO /OUT:wasmedge.lib `${_WASMEDGE_ALL_LIBS} `$<TARGET_OBJECTS:wasmedgeCAPI>"
      $result += "      WORKING_DIRECTORY `${CMAKE_CURRENT_BINARY_DIR}"
      $result += "      DEPENDS `${WASMEDGE_STATIC_LIB_DEPS} wasmedgeCAPI"
      $result += "    )"
      $result += "  elseif(CMAKE_AR_NAME STREQUAL `"libtool`")"
      Write-Host "  Inserted MSVC branch in add_custom_command"
      $i++
      continue
    }

    # --- Patch 1c continued: Replace "add_custom_target(... libwasmedge.a)" block ---
    if ($line.Trim() -eq 'add_custom_target(wasmedge_static_target ALL DEPENDS "libwasmedge.a")') {
      # Skip the old block and write the new MSVC/else block
      # We need to skip until we find the install() for libwasmedge.a
      $result += "  if(MSVC)"
      $result += "    add_custom_target(wasmedge_static_target ALL DEPENDS `"wasmedge.lib`")"
      $result += "    add_library(wasmedge_static STATIC IMPORTED GLOBAL)"
      $result += "    add_dependencies(wasmedge_static wasmedge_static_target)"
      $result += "    set_target_properties(wasmedge_static"
      $result += "      PROPERTIES"
      $result += "      IMPORTED_LOCATION `"`${CMAKE_CURRENT_BINARY_DIR}/wasmedge.lib`""
      $result += "      INTERFACE_INCLUDE_DIRECTORIES `${PROJECT_BINARY_DIR}/include/api"
      $result += "    )"
      $result += "    install(FILES `${CMAKE_CURRENT_BINARY_DIR}/wasmedge.lib"
      $result += "      DESTINATION `${CMAKE_INSTALL_LIBDIR}"
      $result += "      COMPONENT WasmEdge"
      $result += "    )"
      $result += "  else()"
      $result += "    add_custom_target(wasmedge_static_target ALL DEPENDS `"libwasmedge.a`")"
      $result += "    add_library(wasmedge_static STATIC IMPORTED GLOBAL)"
      $result += "    add_dependencies(wasmedge_static wasmedge_static_target)"
      $result += "    set_target_properties(wasmedge_static"
      $result += "      PROPERTIES"
      $result += "      IMPORTED_LOCATION `"`${CMAKE_CURRENT_BINARY_DIR}/libwasmedge.a`""
      $result += "      INTERFACE_INCLUDE_DIRECTORIES `${PROJECT_BINARY_DIR}/include/api"
      $result += "    )"
      $result += "    install(FILES `${CMAKE_CURRENT_BINARY_DIR}/libwasmedge.a"
      $result += "      DESTINATION `${CMAKE_INSTALL_LIBDIR}"
      $result += "      COMPONENT WasmEdge"
      $result += "    )"
      $result += "  endif()"
      Write-Host "  Replaced add_custom_target + set_target_properties + install block"

      # Skip lines until we pass the old install(FILES ... libwasmedge.a) block
      while ($i -lt $lines.Count) {
        if ($lines[$i] -match '^\s*install\(FILES.*libwasmedge\.a') {
          $i++ # skip the install line
          # Also skip closing paren if on next line
          if ($i -lt $lines.Count -and $lines[$i].Trim() -eq ")") { $i++ }
          break
        }
        $i++
      }
      continue
    }

    $result += $line
    $i++
  }
  return $result
}

# ============================================================
# Patch 2: cmake/Helper.cmake
# ============================================================
$file2 = Join-Path $SourceDir "cmake\Helper.cmake"

Patch-File -FilePath $file2 -PatchFunc {
  param([string[]]$lines)
  $result = @()
  $i = 0
  while ($i -lt $lines.Count) {
    $line = $lines[$i]

    # --- Patch 2a: llvm-config flags ---
    # Replace "execute_process(" + "llvm-config --libs --link-static" with MSVC/else
    if ($line -match 'execute_process\(' -and $i + 1 -lt $lines.Count -and $lines[$i + 1] -match 'llvm-config --libs --link-static') {
      $result += "  if(MSVC)"
      $result += "    execute_process("
      $result += "      COMMAND `${LLVM_BINARY_DIR}/bin/llvm-config --libnames"
      # Copy the next line (core lto native...) as-is
      $result += $lines[$i + 2]
      $result += "      OUTPUT_VARIABLE WASMEDGE_LLVM_LINK_LIBS_NAME"
      $result += "    )"
      $result += "    string(REPLACE `".lib`" `"`" WASMEDGE_LLVM_LINK_LIBS_NAME `"`${WASMEDGE_LLVM_LINK_LIBS_NAME}`")"
      $result += "  else()"
      $result += "    execute_process("
      $result += "      COMMAND `${LLVM_BINARY_DIR}/bin/llvm-config --libs --link-static"
      $result += $lines[$i + 2]
      $result += "      OUTPUT_VARIABLE WASMEDGE_LLVM_LINK_LIBS_NAME"
      $result += "    )"
      $result += "    string(REPLACE `"-l`" `"`" WASMEDGE_LLVM_LINK_LIBS_NAME `"`${WASMEDGE_LLVM_LINK_LIBS_NAME}`")"
      $result += "  endif()"
      # Skip original 7 lines (execute_process block + string replace)
      $i += 7
      Write-Host "  Patched llvm-config flags"
      continue
    }

    # --- Patch 2b: LLD + LLVM library names ---
    if ($line.Trim() -eq 'list(APPEND WASMEDGE_LLVM_LINK_STATIC_COMPONENTS' -and
        $i + 1 -lt $lines.Count -and $lines[$i + 1] -match 'liblldELF\.a') {
      $result += "  if(MSVC)"
      $result += "    list(APPEND WASMEDGE_LLVM_LINK_STATIC_COMPONENTS"
      $result += "      `${LLD_LIBRARY_DIR}/lldELF.lib"
      $result += "      `${LLD_LIBRARY_DIR}/lldCommon.lib"
      $result += "    )"
      $result += "    foreach(LIB_NAME IN LISTS WASMEDGE_LLVM_LINK_LIBS_NAME)"
      $result += "      list(APPEND WASMEDGE_LLVM_LINK_STATIC_COMPONENTS"
      $result += "        `${LLVM_LIBRARY_DIR}/${LIB_NAME}.lib"
      $result += "      )"
      $result += "    endforeach()"
      # Skip original block until endif() after lldWasm/liblldWasm
      while ($i -lt $lines.Count -and $lines[$i] -notmatch '^\s*endif\(\)') { $i++ }
      $result += "    if(LLVM_VERSION_MAJOR LESS_EQUAL 13)"
      $result += "      list(APPEND WASMEDGE_LLVM_LINK_STATIC_COMPONENTS"
      $result += "        `${LLD_LIBRARY_DIR}/lldCore.lib"
      $result += "        `${LLD_LIBRARY_DIR}/lldDriver.lib"
      $result += "        `${LLD_LIBRARY_DIR}/lldReaderWriter.lib"
      $result += "        `${LLD_LIBRARY_DIR}/lldYAML.lib"
      $result += "      )"
      $result += "    else()"
      $result += "      list(APPEND WASMEDGE_LLVM_LINK_STATIC_COMPONENTS"
      $result += "        `${LLD_LIBRARY_DIR}/lldMinGW.lib"
      $result += "        `${LLD_LIBRARY_DIR}/lldCOFF.lib"
      $result += "        `${LLD_LIBRARY_DIR}/lldMachO.lib"
      $result += "        `${LLD_LIBRARY_DIR}/lldWasm.lib"
      $result += "      )"
      $result += "    endif()"
      $result += "  else()"
      # Now write the original block
      $result += "    list(APPEND WASMEDGE_LLVM_LINK_STATIC_COMPONENTS"
      $result += "      `${LLD_LIBRARY_DIR}/liblldELF.a"
      $result += "      `${LLD_LIBRARY_DIR}/liblldCommon.a"
      $result += "    )"
      $result += "    foreach(LIB_NAME IN LISTS WASMEDGE_LLVM_LINK_LIBS_NAME)"
      $result += "      list(APPEND WASMEDGE_LLVM_LINK_STATIC_COMPONENTS"
      $result += "        `${LLVM_LIBRARY_DIR}/lib${LIB_NAME}.a"
      $result += "      )"
      $result += "    endforeach()"
      $result += "    if(LLVM_VERSION_MAJOR LESS_EQUAL 13)"
      $result += "      list(APPEND WASMEDGE_LLVM_LINK_STATIC_COMPONENTS"
      $result += "        `${LLD_LIBRARY_DIR}/liblldCore.a"
      $result += "        `${LLD_LIBRARY_DIR}/liblldDriver.a"
      $result += "        `${LLD_LIBRARY_DIR}/liblldReaderWriter.a"
      $result += "        `${LLD_LIBRARY_DIR}/liblldYAML.a"
      $result += "      )"
      $result += "    else()"
      $result += "      list(APPEND WASMEDGE_LLVM_LINK_STATIC_COMPONENTS"
      $result += "        `${LLD_LIBRARY_DIR}/liblldMinGW.a"
      $result += "        `${LLD_LIBRARY_DIR}/liblldCOFF.a"
      $result += "        `${LLD_LIBRARY_DIR}/liblldMachO.a"
      $result += "        `${LLD_LIBRARY_DIR}/liblldWasm.a"
      $result += "      )"
      $result += "    endif()"
      $result += "  endif()"
      # Skip original block
      while ($i -lt $lines.Count) {
        if ($lines[$i].Trim() -eq "endif()" -and $i -gt 0 -and $lines[$i - 1].Trim() -eq "endif()") {
          $i++
          break
        }
        $i++
      }
      Write-Host "  Patched LLD + LLVM library names"
      continue
    }

    # --- Patch 2c: zstd library ---
    if ($line -match 'if\(APPLE OR LLVM_VERSION_MAJOR GREATER_EQUAL 16\)') {
      $result += "    if(APPLE OR LLVM_VERSION_MAJOR GREATER_EQUAL 16 OR MSVC)"
      $result += "      find_package(zstd REQUIRED)"
      $result += "      get_filename_component(ZSTD_PATH `"`${zstd_LIBRARY}`" DIRECTORY)"
      $result += "      if(MSVC)"
      $result += "        list(APPEND WASMEDGE_LLVM_LINK_STATIC_COMPONENTS"
      $result += "          `${ZSTD_PATH}/zstd.lib"
      $result += "        )"
      $result += "      else()"
      $result += "        list(APPEND WASMEDGE_LLVM_LINK_STATIC_COMPONENTS"
      $result += "          `${ZSTD_PATH}/libzstd.a"
      $result += "        )"
      $result += "      endif()"
      $result += "    endif()"
      # Skip original 7 lines
      $i += 7
      Write-Host "  Patched zstd library"
      continue
    }

    $result += $line
    $i++
  }
  return $result
}

Write-Host "=== All MSVC patches applied successfully ==="
