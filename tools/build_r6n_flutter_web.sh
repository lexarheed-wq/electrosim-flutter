#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PNEU="$ROOT/packages/electrosim_pneumatic_solver"
APP="$ROOT/apps/electrosim"
OUT="$ROOT/build/pneumatics-r6n-web-bundle"
mkdir -p "$OUT"

(
  cd "$PNEU"
  dart pub get
  dart compile js -O2 -o "$OUT/r6n_worker.dart.js" tool/r6n_web_worker_main.dart
)
(
  cd "$APP"
  flutter create . --platforms=web --project-name=electrosim
  flutter pub get
  flutter build web --release --dart-define=ELECTROSIM_PNEUMATICS_EXPERIMENTAL=true
)
test -s "$OUT/r6n_worker.dart.js"
test -s "$APP/build/web/main.dart.js"
install -m 0644 "$OUT/r6n_worker.dart.js" "$APP/build/web/r6n_worker.dart.js"
cmp "$OUT/r6n_worker.dart.js" "$APP/build/web/r6n_worker.dart.js"
echo "SOURCE_SHA=$(git -C "$ROOT" rev-parse HEAD)" > "$OUT/PROVENANCE.txt"
echo "FLUTTER_VERSION=$(flutter --version --machine | python3 -c 'import json,sys; print(json.load(sys.stdin)["frameworkVersion"])')" >> "$OUT/PROVENANCE.txt"
echo "WORKER_SHA256=$(sha256sum "$APP/build/web/r6n_worker.dart.js" | cut -d' ' -f1)" >> "$OUT/PROVENANCE.txt"
echo "WORKER_BYTES=$(wc -c < "$APP/build/web/r6n_worker.dart.js")" >> "$OUT/PROVENANCE.txt"
echo "WEB_APP_JS_BYTES=$(wc -c < "$APP/build/web/main.dart.js")" >> "$OUT/PROVENANCE.txt"
cat "$OUT/PROVENANCE.txt"
