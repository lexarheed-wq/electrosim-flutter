#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
if ! command -v flutter >/dev/null 2>&1; then
  for SDK in "$ROOT"/../ElectroSim-Flutter-F*-R*-MONTEREY-CANDIDATE/.toolchain/flutter/bin/flutter; do
    [ -x "$SDK" ] || continue
    export PATH="$(dirname "$SDK"):$PATH"
    break
  done
fi
if ! command -v flutter >/dev/null 2>&1; then
  echo "QUICK_CHECK_BLOCKED: Flutter unavailable. Use ./validate.sh for bootstrap." >&2
  exit 30
fi
cd "$ROOT/packages/electrosim_canvas"
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test test/viewport_controller_test.dart test/hit_test_engine_test.dart test/simulator_canvas_test.dart
if [ -f test/goldens/canvas_compact.png ] && [ -f test/goldens/canvas_medium.png ] && [ -f test/goldens/canvas_expanded.png ]; then
  flutter test test/simulator_canvas_golden_test.dart
fi
flutter test test/canvas_performance_test.dart
echo "F8_QUICK_CHECK_PASS (not an official phase gate)"
