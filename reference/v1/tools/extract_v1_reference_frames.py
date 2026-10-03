#!/usr/bin/env python3
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("video", type=Path)
    ap.add_argument("contract", type=Path)
    ap.add_argument("output_dir", type=Path)
    args = ap.parse_args()
    data = json.loads(args.contract.read_text(encoding="utf-8"))
    expected_video = data["source"]["sha256"]
    actual_video = sha256(args.video)
    if actual_video != expected_video:
        raise SystemExit(
            f"video SHA-256 mismatch: expected {expected_video}, got {actual_video}"
        )
    args.output_dir.mkdir(parents=True, exist_ok=True)
    failures = []
    for state in data["canonical_states"]:
        sid = state["id"].lower()
        timestamp = state["timestamp_seconds"]
        out = args.output_dir / f"{sid}_{timestamp:g}s.jpg"
        subprocess.run(
            [
                "ffmpeg", "-loglevel", "error", "-y", "-ss", str(timestamp),
                "-i", str(args.video), "-frames:v", "1", "-q:v", "2", str(out)
            ],
            check=True,
        )
        got = sha256(out)
        expected = state["frame_sha256"]
        print(f'{state["id"]}: {got}')
        if got != expected:
            failures.append((state["id"], expected, got))
    if failures:
        for sid, expected, got in failures:
            print(f"FAIL {sid}: expected {expected}, got {got}")
        raise SystemExit(1)
    print(
        f'PASS: {len(data["canonical_states"])} canonical reference frames '
        "reproduced exactly"
    )

if __name__ == "__main__":
    main()
