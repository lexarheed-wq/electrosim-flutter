#!/usr/bin/env python3
from __future__ import annotations
import json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VECTORS = ROOT / "test_vectors"
errors: list[str] = []
ids: list[str] = []

expected_files = {
    "dc/DC-001.json", "dc/DC-002.json", "dc/DC-003.json", "dc/DC-004.json", "dc/DC-005.json", "dc/DC-006.json",
    "ac1/AC1-001.json", "ac1/AC1-002.json",
    "ac3/AC3-001.json", "ac3/AC3-002.json", "ac3/AC3-003.json",
    "pv/PV-001.json",
    "faults/FAULT-001.json", "faults/FAULT-002.json", "faults/REPAIR-001.json",
    "system/acceptance_scenarios.json",
}
actual_files = {p.relative_to(VECTORS).as_posix() for p in VECTORS.rglob("*.json")}
for missing in sorted(expected_files - actual_files): errors.append(f"missing-vector:{missing}")
for extra in sorted(actual_files - expected_files): errors.append(f"unexpected-vector:{extra}")

for p in sorted(VECTORS.rglob("*.json")):
    rel = p.relative_to(VECTORS).as_posix()
    try:
        data = json.loads(p.read_text(encoding="utf-8"))
    except Exception as exc:
        errors.append(f"invalid-json:{rel}:{exc}")
        continue
    raw = p.read_text(encoding="utf-8")
    if "exampleId" in raw or "faultId" in raw or "hiddenFaultInjection" in raw and rel != "faults/FAULT-001.json":
        errors.append(f"forbidden-legacy-coupling:{rel}")
    if rel == "system/acceptance_scenarios.json":
        scenarios = data.get("scenarios")
        if not isinstance(scenarios, list) or len(scenarios) != 10:
            errors.append("system-acceptance-count-must-be-10")
            continue
        for s in scenarios:
            sid = s.get("id")
            if not isinstance(sid, str) or not re.fullmatch(r"SA-(0[1-9]|10)", sid):
                errors.append(f"invalid-system-id:{sid!r}")
            else:
                ids.append(sid)
        continue
    vid = data.get("id")
    if not isinstance(vid, str) or not vid:
        errors.append(f"missing-id:{rel}")
    else:
        ids.append(vid)
    if "expected" not in data or not isinstance(data["expected"], dict):
        errors.append(f"missing-expected:{rel}")

if len(ids) != len(set(ids)):
    errors.append("duplicate-vector-id")
required_ids = {
    *(f"DC-{i:03d}" for i in range(1,7)),
    "AC1-001","AC1-002","AC3-001","AC3-002","AC3-003","PV-001","FAULT-001","FAULT-002","REPAIR-001",
    *(f"SA-{i:02d}" for i in range(1,11)),
}
for missing in sorted(required_ids - set(ids)): errors.append(f"missing-required-id:{missing}")

payload={"status":"PASS" if not errors else "FAIL","errors":errors,"ids":sorted(ids),"count":len(ids)}
print(json.dumps(payload,indent=2,ensure_ascii=False))
sys.exit(0 if not errors else 1)
