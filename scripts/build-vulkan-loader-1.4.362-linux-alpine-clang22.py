#!/usr/bin/env python3
"""Patch Vulkan-Loader for Linux Alpine musl static build.

No patches required for musl — Vulkan-Loader builds cleanly on Alpine.
This script exists for consistency with the prebuilt scripts convention.
"""
import sys


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <Vulkan-Loader-source-dir>")
        sys.exit(1)

    print(f"Vulkan-Loader source: {sys.argv[1]}")
    print("No patches needed for Alpine musl — skipping.")
