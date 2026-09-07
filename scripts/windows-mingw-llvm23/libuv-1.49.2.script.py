#!/usr/bin/env python3
"""Patch libuv for Windows MinGW static build.

No patches required for libuv — it builds cleanly with MinGW.
This script exists for consistency with the prebuilt scripts convention.
"""
import sys


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <libuv-source-dir>")
        sys.exit(1)

    print(f"libuv source: {sys.argv[1]}")
    print("No patches needed for MinGW — skipping.")
