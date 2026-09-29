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
  if find test -type f -name '*_test.dart' -print -quit 2>/dev/null | grep -q .; then
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
if [ -f tools/architecture_guard.dart ]; then
  echo "=== architecture guard ==="
  dart tools/architecture_guard.dart
fi

echo "RC1_TRANSVERSAL_GATE_PASS"
