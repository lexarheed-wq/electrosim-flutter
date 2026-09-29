#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import platform
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUDIT = Path(os.getenv("F0_AUDIT_DIR", str(ROOT / "audit")))
AUDIT.mkdir(parents=True, exist_ok=True)


def run_version(cmd: list[str]) -> dict:
    exe = shutil.which(cmd[0])
    if not exe:
        return {"available": False, "executable": None, "output": None}
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        output = (proc.stdout + proc.stderr).strip()
        return {
            "available": proc.returncode == 0,
            "executable": exe,
            "returncode": proc.returncode,
            "output": output,
        }
    except Exception as exc:  # explicit audit, never silent success
        return {"available": False, "executable": exe, "error": repr(exc)}


payload = {
    "generatedAt": datetime.now(timezone.utc).isoformat(),
    "platform": {
        "system": platform.system(),
        "release": platform.release(),
        "machine": platform.machine(),
        "python": sys.version.split()[0],
    },
    "environment": {
        "CI": os.getenv("CI"),
        "GITHUB_ACTIONS": os.getenv("GITHUB_ACTIONS"),
    },
    "flutter": run_version(["flutter", "--version"]),
    "dart": run_version(["dart", "--version"]),
    "git": run_version(["git", "--version"]),
}

path = AUDIT / "toolchain_runtime.json"
path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n")
print(json.dumps(payload, indent=2, ensure_ascii=False))
