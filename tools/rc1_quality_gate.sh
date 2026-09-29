#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export CI=true

echo "=== ElectroSim 2 RC1 transversal quality gate ==="

run_target() {
  local dir="$1"
  echo "=== analyze: $dir ==="
  cd "$ROOT/$dir"
  flutter pub get
  dart analyze

  mapfile -t tests < <(find test -type f -name '*_test.dart' ! -name '*_golden_test.dart' ! -name '*_goldens_test.dart' | sort 2>/dev/null || true)
  if [ "${#tests[@]}" -gt 0 ]; then
    echo "=== test: $dir (portable non-golden suite) ==="
    flutter test "${tests[@]}"
  else
    echo "=== test: $dir (no portable tests) ==="
  fi
}

run_target "apps/electrosim"

for dir in "$ROOT"/packages/*; do
  [ -f "$dir/pubspec.yaml" ] || continue
  rel="packages/$(basename "$dir")"
  run_target "$rel"
done

cd "$ROOT"
echo "=== frozen visual baseline integrity ==="
python3 tools/verify_f8_golden_baseline.py
python3 tools/verify_f9_manifest.py

if [ -f tools/architecture_guard.dart ]; then
  echo "=== architecture guard ==="
  dart tools/architecture_guard.dart
fi

echo "RC1_TRANSVERSAL_GATE_PASS"
