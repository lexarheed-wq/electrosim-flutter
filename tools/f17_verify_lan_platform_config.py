#!/usr/bin/env python3
"""Verify ElectroSim LAN permissions/configuration on generated Flutter runners."""

from __future__ import annotations

import argparse
import plistlib
import xml.etree.ElementTree as ET
from pathlib import Path

ANDROID_NS = "http://schemas.android.com/apk/res/android"
ANDROID_NAME = f"{{{ANDROID_NS}}}name"
ANDROID_CLEARTEXT = f"{{{ANDROID_NS}}}usesCleartextTraffic"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit("F17_LAN_PLATFORM_CONFIG_FAIL " + message)


def verify_android(app: Path) -> None:
    manifest = app / "android/app/src/main/AndroidManifest.xml"
    require(manifest.is_file(), f"missing {manifest}")
    root = ET.parse(manifest).getroot()
    permissions = {
        item.get(ANDROID_NAME)
        for item in root.findall("uses-permission")
    }
    require(
        "android.permission.INTERNET" in permissions,
        "android INTERNET permission missing",
    )
    application = root.find("application")
    require(application is not None, "android application element missing")
    require(
        application.get(ANDROID_CLEARTEXT) == "true",
        "android cleartext websocket allowance missing",
    )


def _load_plist(path: Path) -> dict:
    require(path.is_file(), f"missing {path}")
    with path.open("rb") as handle:
        value = plistlib.load(handle)
    require(isinstance(value, dict), f"invalid plist {path}")
    return value


def verify_apple_info(path: Path, platform: str) -> None:
    data = _load_plist(path)
    description = data.get("NSLocalNetworkUsageDescription")
    require(
        isinstance(description, str) and description.strip(),
        f"{platform} NSLocalNetworkUsageDescription missing",
    )
    ats = data.get("NSAppTransportSecurity")
    require(isinstance(ats, dict), f"{platform} NSAppTransportSecurity missing")
    require(
        ats.get("NSAllowsLocalNetworking") is True,
        f"{platform} NSAllowsLocalNetworking missing",
    )


def verify_ios(app: Path) -> None:
    verify_apple_info(app / "ios/Runner/Info.plist", "ios")


def verify_macos(app: Path) -> None:
    verify_apple_info(app / "macos/Runner/Info.plist", "macos")
    for name in ("DebugProfile.entitlements", "Release.entitlements"):
        data = _load_plist(app / "macos/Runner" / name)
        require(
            data.get("com.apple.security.network.client") is True,
            f"macos {name} network client entitlement missing",
        )
        require(
            data.get("com.apple.security.network.server") is True,
            f"macos {name} network server entitlement missing",
        )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("app", type=Path)
    parser.add_argument(
        "target",
        choices=("android", "ios", "macos", "linux", "windows", "web"),
    )
    args = parser.parse_args()

    app = args.app.resolve()
    if args.target == "android":
        verify_android(app)
    elif args.target == "ios":
        verify_ios(app)
    elif args.target == "macos":
        verify_macos(app)

    print(f"F17_LAN_PLATFORM_CONFIG_PASS {args.target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
