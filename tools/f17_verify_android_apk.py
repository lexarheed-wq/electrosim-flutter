#!/usr/bin/env python3
"""Verify the built Android artifact remains compatible with ElectroSim LAN sync."""

from __future__ import annotations

import argparse
import os
import re
import subprocess
from pathlib import Path


def find_aapt() -> Path:
    root = Path(os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT") or "")
    if not root.is_dir():
        raise SystemExit("F17_ANDROID_APK_FAIL Android SDK root unavailable")
    candidates = sorted(
        (root / "build-tools").glob("*/aapt"),
        key=lambda path: tuple(
            int(part) if part.isdigit() else 0
            for part in path.parent.name.replace("-", ".").split(".")
        ),
        reverse=True,
    )
    if not candidates:
        raise SystemExit("F17_ANDROID_APK_FAIL aapt unavailable")
    return candidates[0]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("apk", type=Path)
    args = parser.parse_args()

    apk = args.apk.resolve()
    if not apk.is_file():
        raise SystemExit(f"F17_ANDROID_APK_FAIL missing APK: {apk}")

    aapt = find_aapt()
    output = subprocess.check_output(
        [str(aapt), "dump", "badging", str(apk)],
        text=True,
        stderr=subprocess.STDOUT,
    )

    target_match = re.search(r"targetSdkVersion:'(\d+)'", output)
    if target_match is None:
        raise SystemExit("F17_ANDROID_APK_FAIL targetSdkVersion unavailable")
    target_sdk = int(target_match.group(1))

    if "uses-permission: name='android.permission.INTERNET'" not in output:
        raise SystemExit("F17_ANDROID_APK_FAIL INTERNET permission missing")

    # Android 17 / API 37 makes LAN access a runtime permission. ElectroSim
    # currently qualifies the direct classroom WebSocket path on target SDK
    # <=36. Fail loudly if the toolchain target changes so this can never
    # become a silent runtime regression.
    if target_sdk >= 37:
        raise SystemExit(
            "F17_ANDROID_APK_FAIL targetSdkVersion >= 37 requires "
            "ACCESS_LOCAL_NETWORK runtime permission integration"
        )

    print(f"F17_ANDROID_APK_PASS targetSdkVersion={target_sdk}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
