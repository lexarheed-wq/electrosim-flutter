#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if ! command -v flutter >/dev/null 2>&1; then
  for SDK in "$ROOT"/../ElectroSim-Flutter-F*-MONTEREY-CANDIDATE/.toolchain/flutter/bin/flutter; do
    [ -x "$SDK" ] || continue
    SDK_BIN="$(dirname "$SDK")"; echo "Reusing existing Flutter SDK: $SDK_BIN"; export PATH="$SDK_BIN:$PATH"; break
  done
fi
if command -v flutter >/dev/null 2>&1 && command -v dart >/dev/null 2>&1; then exec "$ROOT/tools/run_f9_r11_gate.sh"; fi
exec "$ROOT/tools/bootstrap_flutter_f9_r11_fallback.sh"
