#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${1:?target required}"
TMP_ROOT="${2:-}"

if [ -n "$TMP_ROOT" ]; then
  PREP_OUT="$("$ROOT/tools/f15_prepare_runner.sh" "$TARGET" "$TMP_ROOT")"
else
  PREP_OUT="$("$ROOT/tools/f15_prepare_runner.sh" "$TARGET")"
fi

case "$PREP_OUT" in
  F15_RUNNER_PATH=*) TMP="${PREP_OUT#F15_RUNNER_PATH=}" ;;
  *) echo "F17_RUNNER_PATH_PROTOCOL_ERROR: $PREP_OUT" >&2; exit 69 ;;
esac

APP="$TMP/apps/electrosim"
python3 "$ROOT/tools/f17_apply_lan_platform_config.py" "$APP" "$TARGET"
python3 "$ROOT/tools/f17_apply_lan_platform_config.py" "$APP" "$TARGET" --check

printf 'F17_RUNNER_PATH=%s\n' "$TMP"
