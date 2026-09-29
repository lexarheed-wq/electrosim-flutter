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

  if [ "$dir" = "apps/electrosim" ]; then
    mapfile -t tests < <(find test -type f -name '*_test.dart' ! -name 'f9_goldens_test.dart' | sort)
    if [ "${#tests[@]}" -gt 0 ]; then
      echo "=== test: $dir (portable suite; F9 golden pixels verified by frozen manifest) ==="
      flutter test "${tests[@]}"
    fi
  elif find test -type f -name '*_test.dart' -print -quit 2>/dev/null | grep -q .; then
    echo "=== test: $dir ==="
    flutter test
  else
    echo "=== test: $dir (no tests) ==="
  fi
}

run_target "apps/electrosim"

for dir in "$ROOT"/packages/*; do
  [ -f "$dir/pubspec.yaml" ] || continue
  rel="packages/$(basename "$dir")"
  run_target "$rel"
done

cd "$ROOT"
echo "=== frozen F9 visual baseline integrity ==="
python3 tools/verify_f9_manifest.py

if [ -f tools/architecture_guard.dart ]; then
  echo "=== architecture guard ==="
  dart tools/architecture_guard.dart
fi

echo "RC1_TRANSVERSAL_GATE_PASS"
