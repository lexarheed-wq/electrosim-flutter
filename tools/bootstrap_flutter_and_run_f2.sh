#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Prefer an already extracted, validated sibling SDK. This makes later phases a
# one-command validation and avoids repeated 2 GB downloads/extractions.
if ! command -v flutter >/dev/null 2>&1; then
  for SDK in "$ROOT"/../ElectroSim-Flutter-F*-MONTEREY-CANDIDATE/.toolchain/flutter/bin/flutter; do
    [ -x "$SDK" ] || continue
    SDK_BIN="$(dirname "$SDK")"
    echo "Reusing existing Flutter SDK: $SDK_BIN"
    export PATH="$SDK_BIN:$PATH"
    break
  done
fi

if command -v flutter >/dev/null 2>&1 && command -v dart >/dev/null 2>&1; then
  exec "$ROOT/tools/run_f2_gate.sh"
fi

# Fallback: use the locked installer. It will reuse a verified archive from a
# sibling candidate whenever available.
exec "$ROOT/tools/bootstrap_flutter_f2_fallback.sh"
