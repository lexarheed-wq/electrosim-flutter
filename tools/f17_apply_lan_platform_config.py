#!/usr/bin/env python3
"""Apply and verify ElectroSim LAN permissions on generated Flutter runners.

ElectroSim intentionally does not version generated platform directories. This
script is therefore run immediately after `flutter create --platforms=...` so
release runners receive the permissions required by the F17-R11 classroom LAN
transport.
"""

from __future__ import annotations

import plistlib
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ANDROID_NS = "http://schemas.android.com/apk/res/android"
ANDROID_NAME = f"{{{ANDROID_NS}}}name"
ANDROID_CLEARTEXT = f"{{{ANDROID_NS}}}usesCleartextTraffic"


class ConfigError(RuntimeError):
    pass


def _load_plist(path: Path) -> dict:
    if not path.is_file():
        raise ConfigError(f"missing plist: {path}")
    with path.open("rb") as handle:
        data = plistlib.load(handle)
    if not isinstance(data, dict):
        raise ConfigError(f"invalid plist root: {path}")
    return data


def _write_plist(path: Path, data: dict) -> None:
    with path.open("wb") as handle:
        plistlib.dump(data, handle, fmt=plistlib.FMT_XML, sort_keys=False)


def _android_manifest(app: Path) -> Path:
    return app / "android" / "app" / "src" / "main" / "AndroidManifest.xml"


def apply_android(app: Path) -> None:
    path = _android_manifest(app)
    if not path.is_file():
        raise ConfigError(f"missing Android manifest: {path}")

    ET.register_namespace("android", ANDROID_NS)
    tree = ET.parse(path)
    root = tree.getroot()

    internet = any(
        node.tag == "uses-permission"
        and node.attrib.get(ANDROID_NAME) == "android.permission.INTERNET"
        for node in root
    )
    if not internet:
        permission = ET.Element("uses-permission")
        permission.set(ANDROID_NAME, "android.permission.INTERNET")
        root.insert(0, permission)

    application = root.find("application")
    if application is None:
        raise ConfigError("Android manifest has no <application>")
    # R11 deliberately uses ws:// on a trusted classroom LAN. Android blocks
    # cleartext HTTP/WebSocket traffic by default on modern target SDKs.
    application.set(ANDROID_CLEARTEXT, "true")

    tree.write(path, encoding="utf-8", xml_declaration=True)


def check_android(app: Path) -> None:
    path = _android_manifest(app)
    tree = ET.parse(path)
    root = tree.getroot()
    permissions = {
        node.attrib.get(ANDROID_NAME)
        for node in root
        if node.tag == "uses-permission"
    }
    if "android.permission.INTERNET" not in permissions:
        raise ConfigError("Android INTERNET permission missing")
    application = root.find("application")
    if application is None:
        raise ConfigError("Android manifest has no <application>")
    if application.attrib.get(ANDROID_CLEARTEXT) != "true":
        raise ConfigError("Android cleartext WebSocket traffic is not enabled")


def apply_ios(app: Path) -> None:
    path = app / "ios" / "Runner" / "Info.plist"
    data = _load_plist(path)
    data["NSLocalNetworkUsageDescription"] = (
        "ElectroSim utilise le réseau local pour synchroniser la session "
        "professeur/élèves dans la salle de classe."
    )
    ats = data.get("NSAppTransportSecurity")
    if not isinstance(ats, dict):
        ats = {}
        data["NSAppTransportSecurity"] = ats
    ats["NSAllowsLocalNetworking"] = True
    _write_plist(path, data)


def check_ios(app: Path) -> None:
    path = app / "ios" / "Runner" / "Info.plist"
    data = _load_plist(path)
    description = data.get("NSLocalNetworkUsageDescription")
    if not isinstance(description, str) or not description.strip():
        raise ConfigError("iOS local-network usage description missing")
    ats = data.get("NSAppTransportSecurity")
    if not isinstance(ats, dict) or ats.get("NSAllowsLocalNetworking") is not True:
        raise ConfigError("iOS NSAllowsLocalNetworking is not enabled")


def _macos_entitlements(app: Path) -> list[Path]:
    runner = app / "macos" / "Runner"
    return [
        runner / "DebugProfile.entitlements",
        runner / "Release.entitlements",
    ]


def apply_macos(app: Path) -> None:
    for path in _macos_entitlements(app):
        data = _load_plist(path)
        # The same binary can act as teacher (server) or student (client).
        data["com.apple.security.network.client"] = True
        data["com.apple.security.network.server"] = True
        # P3: permit writing documents explicitly selected in the native
        # macOS save dialog, without broad filesystem access.
        data["com.apple.security.files.user-selected.read-write"] = True
        _write_plist(path, data)


def check_macos(app: Path) -> None:
    for path in _macos_entitlements(app):
        data = _load_plist(path)
        if data.get("com.apple.security.network.client") is not True:
            raise ConfigError(f"macOS network.client entitlement missing: {path.name}")
        if data.get("com.apple.security.network.server") is not True:
            raise ConfigError(f"macOS network.server entitlement missing: {path.name}")
        if data.get("com.apple.security.files.user-selected.read-write") is not True:
            raise ConfigError(f"macOS user-selected read-write entitlement missing: {path.name}")


def apply(app: Path, target: str) -> None:
    if target == "android":
        apply_android(app)
    elif target == "ios":
        apply_ios(app)
    elif target == "macos":
        apply_macos(app)
    elif target in {"linux", "windows"}:
        return
    else:
        raise ConfigError(f"unsupported F17 native target: {target}")


def check(app: Path, target: str) -> None:
    if target == "android":
        check_android(app)
    elif target == "ios":
        check_ios(app)
    elif target == "macos":
        check_macos(app)
    elif target in {"linux", "windows"}:
        return
    else:
        raise ConfigError(f"unsupported F17 native target: {target}")


def main(argv: list[str]) -> int:
    if len(argv) not in {3, 4}:
        print(
            "usage: f17_apply_lan_platform_config.py APP_ROOT TARGET [--check]",
            file=sys.stderr,
        )
        return 64

    app = Path(argv[1]).resolve()
    target = argv[2].lower()
    check_only = len(argv) == 4 and argv[3] == "--check"
    if len(argv) == 4 and not check_only:
        print(f"unknown option: {argv[3]}", file=sys.stderr)
        return 64

    try:
        if not check_only:
            apply(app, target)
        check(app, target)
    except (ConfigError, OSError, ET.ParseError, plistlib.InvalidFileException) as exc:
        print(f"F17_LAN_PLATFORM_CONFIG_FAIL {target}: {exc}", file=sys.stderr)
        return 2

    print(f"F17_LAN_PLATFORM_CONFIG_PASS {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
