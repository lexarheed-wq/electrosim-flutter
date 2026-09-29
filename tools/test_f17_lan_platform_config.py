#!/usr/bin/env python3
"""Regression tests for generated LAN platform configuration."""

from __future__ import annotations

import plistlib
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APPLY = ROOT / "tools/f17_apply_lan_platform_config.py"
VERIFY = ROOT / "tools/f17_verify_lan_platform_config.py"


def write_plist(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as handle:
        plistlib.dump(value, handle)


def run(*args: str) -> None:
    subprocess.run([sys.executable, *args], check=True)


def test_android(app: Path) -> None:
    manifest = app / "android/app/src/main/AndroidManifest.xml"
    manifest.parent.mkdir(parents=True, exist_ok=True)
    manifest.write_text(
        """<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:label="electrosim" />
</manifest>
""",
        encoding="utf-8",
    )
    run(str(APPLY), str(app), "android")
    run(str(APPLY), str(app), "android")
    run(str(VERIFY), str(app), "android")
    text = manifest.read_text(encoding="utf-8")
    assert text.count("android.permission.INTERNET") == 1
    assert 'android:usesCleartextTraffic="true"' in text


def test_ios(app: Path) -> None:
    info = app / "ios/Runner/Info.plist"
    write_plist(info, {"CFBundleName": "ElectroSim"})
    run(str(APPLY), str(app), "ios")
    run(str(APPLY), str(app), "ios")
    run(str(VERIFY), str(app), "ios")
    with info.open("rb") as handle:
        data = plistlib.load(handle)
    assert data["NSLocalNetworkUsageDescription"]
    assert data["NSAppTransportSecurity"]["NSAllowsLocalNetworking"] is True


def test_macos(app: Path) -> None:
    info = app / "macos/Runner/Info.plist"
    write_plist(info, {"CFBundleName": "ElectroSim"})
    for name in ("DebugProfile.entitlements", "Release.entitlements"):
        write_plist(
            app / "macos/Runner" / name,
            {"com.apple.security.app-sandbox": True},
        )
    run(str(APPLY), str(app), "macos")
    run(str(APPLY), str(app), "macos")
    run(str(VERIFY), str(app), "macos")
    for name in ("DebugProfile.entitlements", "Release.entitlements"):
        with (app / "macos/Runner" / name).open("rb") as handle:
            data = plistlib.load(handle)
        assert data["com.apple.security.network.client"] is True
        assert data["com.apple.security.network.server"] is True


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="electrosim-lan-config-") as raw:
        root = Path(raw)
        test_android(root / "android-app")
        test_ios(root / "ios-app")
        test_macos(root / "macos-app")
    print("F17_LAN_PLATFORM_TOOLING_PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
