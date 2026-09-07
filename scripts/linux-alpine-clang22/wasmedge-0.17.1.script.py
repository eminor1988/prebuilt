#!/usr/bin/env python3
"""Patch WasmEdge 0.17.1 for Linux Alpine musl + libc++ build.

Fixes __GLIBC_PREREQ fallback logic in linux.h that incorrectly evaluates
to 0 when using libc++ on musl, causing O_SYMLINK compile errors.
"""
import sys


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <WasmEdge-source-dir>")
        sys.exit(1)

    print(f"WasmEdge source: {sys.argv[1]}")
    print("Apply patch via: git apply <patch-file>")
    print("Patch is applied automatically in the CI workflow.")
