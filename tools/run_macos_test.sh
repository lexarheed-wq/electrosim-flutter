#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "Ce lanceur est réservé à macOS." >&2
  exit 64
fi

source "$ROOT/tools/f15_flutter_env.sh"

VERSION="$(cat "$ROOT/VERSION" 2>/dev/null || echo unknown)"
echo "ElectroSim version: $VERSION"
echo "Flutter: $("$FLUTTER_BIN" --version | head -1)"

TMP_ROOT="${TMPDIR:-/tmp}/electrosim-macos-live"
rm -rf "$TMP_ROOT"
mkdir -p "$TMP_ROOT/apps"

cp -R "$ROOT/apps/electrosim" "$TMP_ROOT/apps/electrosim"
cp -R "$ROOT/packages" "$TMP_ROOT/packages"

APP="$TMP_ROOT/apps/electrosim"
cd "$APP"

cp pubspec.yaml "$TMP_ROOT/pubspec.electrosim.yaml"
"$FLUTTER_BIN" create --platforms=macos --project-name electrosim . >/dev/null
cp "$TMP_ROOT/pubspec.electrosim.yaml" pubspec.yaml
python3 "$ROOT/tools/f17_apply_lan_platform_config.py" "$APP" macos
python3 "$ROOT/tools/f17_apply_lan_platform_config.py" "$APP" macos --check

if [ -f test/widget_test.dart ] && grep -q "MyApp" test/widget_test.dart; then
  rm -f test/widget_test.dart
fi

"$FLUTTER_BIN" pub get
echo "Building offline ElectroSim student Web client..."
rm -rf "$APP/build/student_web"
"$FLUTTER_BIN" build web --release -t lib/student_web_main.dart
mv "$APP/build/web" "$APP/build/student_web"
export ELECTROSIM_STUDENT_WEB_ROOT="$APP/build/student_web"

echo
echo "============================================================"
echo "ElectroSim est prêt pour le test macOS."
echo "Fermez l'application ou faites Ctrl+C dans Terminal pour arrêter."
echo "============================================================"
echo

exec "$FLUTTER_BIN" run -d macos
