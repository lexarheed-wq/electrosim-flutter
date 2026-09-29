#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCK="$ROOT/ci/TOOLCHAIN_LOCK.json"
REQUIRED="$(python3 - "$LOCK" <<'PY'
import json,sys
print(json.load(open(sys.argv[1],encoding='utf-8'))['flutter']['version'])
PY
)"
valid_flutter(){ local f="$1" out actual; [ -x "$f" ] || return 1; out="$($f --version 2>&1 || true)"; actual="$(awk 'NR==1 && $1=="Flutter" {print $2}' <<< "$out")"; [ "$actual" = "$REQUIRED" ]; }
for SDK in \
  "$ROOT/.toolchain/flutter/bin/flutter" \
  "$ROOT"/../ElectroSim-Flutter-F9-FINAL-VENTURA-FIX10-CANDIDATE/.toolchain/flutter/bin/flutter \
  "$ROOT"/../ElectroSim-Flutter-F10-*/.toolchain/flutter/bin/flutter \
  "$ROOT"/../ElectroSim-Flutter-F11-*/.toolchain/flutter/bin/flutter \
  "$ROOT"/../ElectroSim-Flutter-*/.toolchain/flutter/bin/flutter; do
  if valid_flutter "$SDK"; then export PATH="$(dirname "$SDK"):$PATH"; echo "Using locked local Flutter SDK: $SDK"; exec "$ROOT/tools/run_f12_gate.sh"; fi
done
if command -v flutter >/dev/null 2>&1 && valid_flutter "$(command -v flutter)"; then exec "$ROOT/tools/run_f12_gate.sh"; fi
"$ROOT/bootstrap_local_toolchain.sh"
export PATH="$ROOT/.toolchain/flutter/bin:$PATH"
exec "$ROOT/tools/run_f12_gate.sh"
