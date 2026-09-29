#!/usr/bin/env python3
"""Apply ElectroSim LAN permissions/configuration to generated Flutter runners."""

from __future__ import annotations

import argparse
import plistlib
import xml.etree.ElementTree as ET
from pathlib import Path

ANDROID_NS = "http://schemas.android.com/apk/res/android"
ET.register_namespace("android", ANDROID_NS)
ANDROID_NAME = f"{{{ANDROID_NS}}}name"
ANDROID_CLEARTEXT = f"{{{ANDROID_NS}}}usesCleartextTraffic"

LOCAL_NETWORK_MESSAGE = (
    "ElectroSim utilise le réseau local pour synchroniser une session "
    "professeur/élève entre appareils de la même salle."
)


def _write_plist(path: Path, data: dict) -> None:
    with path.open("wb") as handle:
        plistlib.dump(data, handle, fmt=plistlib.FMT_XML, sort_keys=False)


def patch_android(app: Path) -> None:
    manifest = app / "android/app/src/main/AndroidManifest.xml"
    if not manifest.is_file():
        raise SystemExit(f"Missing Android manifest: {manifest}")

    tree = ET.parse(manifest)
    root = tree.getroot()

    internet = "android.permission.INTERNET"
    existing = {
        child.get(ANDROID_NAME)
        for child in root.findall("uses-permission")
    }
    if internet not in existing:
        permission = ET.Element("uses-permission")
        permission.set(ANDROID_NAME, internet)
        application = root.find("application")
        index = list(root).index(application) if application is not None else 0
        root.insert(index, permission)

    application = root.find("application")
    if application is None:
        raise SystemExit("Android manifest has no <application> element.")
    application.set(ANDROID_CLEARTEXT, "true")

    ET.indent(tree, space="    ")
    tree.write(manifest, encoding="utf-8", xml_declaration=True)


def patch_ios(app: Path) -> None:
    info = app / "ios/Runner/Info.plist"
    if not info.is_file():
        raise SystemExit(f"Missing iOS Info.plist: {info}")
    with info.open("rb") as handle:
        data = plistlib.load(handle)

    data["NSLocalNetworkUsageDescription"] = LOCAL_NETWORK_MESSAGE
    ats = data.get("NSAppTransportSecurity")
    if not isinstance(ats, dict):
        ats = {}
        data["NSAppTransportSecurity"] = ats
    ats["NSAllowsLocalNetworking"] = True
    _write_plist(info, data)


def patch_macos(app: Path) -> None:
    info = app / "macos/Runner/Info.plist"
    if not info.is_file():
        raise SystemExit(f"Missing macOS Info.plist: {info}")
    with info.open("rb") as handle:
        data = plistlib.load(handle)

    data["NSLocalNetworkUsageDescription"] = LOCAL_NETWORK_MESSAGE
    ats = data.get("NSAppTransportSecurity")
    if not isinstance(ats, dict):
        ats = {}
        data["NSAppTransportSecurity"] = ats
    ats["NSAllowsLocalNetworking"] = True
    _write_plist(info, data)

    for name in ("DebugProfile.entitlements", "Release.entitlements"):
        entitlements = app / "macos/Runner" / name
        if not entitlements.is_file():
            raise SystemExit(f"Missing macOS entitlements: {entitlements}")
        with entitlements.open("rb") as handle:
            values = plistlib.load(handle)
        values["com.apple.security.network.client"] = True
        values["com.apple.security.network.server"] = True
        _write_plist(entitlements, values)


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
        patch_android(app)
    elif args.target == "ios":
        patch_ios(app)
    elif args.target == "macos":
        patch_macos(app)

    print(f"F17_LAN_PLATFORM_CONFIG_APPLIED {args.target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
