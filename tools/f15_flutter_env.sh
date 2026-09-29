#!/usr/bin/env bash
# Source this file from F15 scripts that need Flutter/Dart.
# Resolves the project-locked Flutter 3.38.10 toolchain without relying on a global PATH.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK="$ROOT/ci/TOOLCHAIN_LOCK.json"
REQUIRED_FLUTTER="$(python3 - "$LOCK" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
print(x['flutter']['version'])
PY
)"
REQUIRED_DART="$(python3 - "$LOCK" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
print(x['flutter']['dartVersion'])
PY
)"
valid_sdk() {
  local f="$1" out fv d
  [ -x "$f" ] || return 1
  out="$("$f" --version 2>&1 || true)"
  fv="$(awk 'NR==1 && $1=="Flutter" {print $2}' <<< "$out")"
  [ "$fv" = "$REQUIRED_FLUTTER" ] || return 1
  d="$(dirname "$f")/cache/dart-sdk/bin/dart"
  [ -x "$d" ] || return 1
  local dv
  dv="$("$d" --version 2>&1 | sed -E 's/^Dart SDK version: ([0-9.]+).*/\1/' | head -1)"
  [ "$dv" = "$REQUIRED_DART" ]
}
SDK=""
# Prefer this candidate, then known validated neighboring candidates.
shopt -s nullglob
CANDIDATES=(
  "$ROOT/.toolchain/flutter/bin/flutter"
  "$ROOT"/../ElectroSim-Flutter-F9-FINAL-VENTURA-FIX10-CANDIDATE/.toolchain/flutter/bin/flutter
  "$ROOT"/../ElectroSim-Flutter-F1[0-9]-*/.toolchain/flutter/bin/flutter
  "$ROOT"/../ElectroSim-Flutter-*/.toolchain/flutter/bin/flutter
)
for f in "${CANDIDATES[@]}"; do
  if valid_sdk "$f"; then SDK="$f"; break; fi
done
shopt -u nullglob
if [ -z "$SDK" ] && command -v flutter >/dev/null 2>&1 && valid_sdk "$(command -v flutter)"; then
  SDK="$(command -v flutter)"
fi
if [ -z "$SDK" ]; then
  # Offline bootstrap only; it never downloads from the network.
  "$ROOT/bootstrap_local_toolchain.sh" >/dev/null
  SDK="$ROOT/.toolchain/flutter/bin/flutter"
  valid_sdk "$SDK" || { echo "F15_LOCKED_FLUTTER_NOT_FOUND" >&2; exit 68; }
fi
export FLUTTER_BIN="$SDK"
export DART_BIN="$(dirname "$SDK")/cache/dart-sdk/bin/dart"
export PATH="$(dirname "$SDK"):$(dirname "$DART_BIN"):$PATH"
export FLUTTER_SUPPRESS_ANALYTICS=true
