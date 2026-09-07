#!/usr/bin/env python3
"""Patch libuv for Linux Alpine musl static build.

No patches required for libuv — it builds cleanly on Alpine musl.
This script exists for consistency with the prebuilt scripts convention.
"""
import sys


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <libuv-source-dir>")
        sys.exit(1)

    print(f"libuv source: {sys.argv[1]}")
    print("No patches needed for Alpine musl — skipping.")
