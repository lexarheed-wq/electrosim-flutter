#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tools/f15_flutter_env.sh"
qualify_if_available(){
  local target="$1" out rc
  set +e
  out="$($ROOT/tools/f15_platform_preflight.sh "$target" 2>&1)"
  rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    "$ROOT/tools/f15_qualify_target.sh" "$target"
    return 0
  fi
  if [ "$rc" -eq 3 ]; then
    echo "$out"
    return 0
  fi
  echo "$out" >&2
  return "$rc"
}
HOST="$(uname -s)"
case "$HOST" in
  Darwin)
    qualify_if_available macos
    qualify_if_available ios
    ;;
  Linux)
    qualify_if_available linux
    ;;
  MINGW*|MSYS*|CYGWIN*) qualify_if_available windows ;;
  *) echo "Unsupported host: $HOST" >&2; exit 2 ;;
esac
qualify_if_available android
