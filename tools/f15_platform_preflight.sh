#!/usr/bin/env bash
set -euo pipefail
TARGET="${1:?target required}"
case "$TARGET" in
  macos)
    [ "$(uname -s)" = "Darwin" ] || { echo "F15_TARGET_UNAVAILABLE macos host-not-darwin"; exit 3; }
    ;;
  ios)
    [ "$(uname -s)" = "Darwin" ] || { echo "F15_TARGET_UNAVAILABLE ios host-not-darwin"; exit 3; }
    command -v xcodebuild >/dev/null 2>&1 || { echo "F15_TARGET_UNAVAILABLE ios xcodebuild-missing"; exit 3; }
    if ! xcrun --sdk iphoneos --show-sdk-path >/dev/null 2>&1; then
      echo "F15_TARGET_UNAVAILABLE ios iphoneos-sdk-missing"
      exit 3
    fi
    ;;
  linux)
    [ "$(uname -s)" = "Linux" ] || { echo "F15_TARGET_UNAVAILABLE linux host-not-linux"; exit 3; }
    ;;
  windows)
    case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) ;; *) [ "${OS:-}" = "Windows_NT" ] || { echo "F15_TARGET_UNAVAILABLE windows host-not-windows"; exit 3; };; esac
    ;;
  android)
    if ! command -v adb >/dev/null 2>&1 && [ -z "${ANDROID_HOME:-}" ] && [ -z "${ANDROID_SDK_ROOT:-}" ]; then
      echo "F15_TARGET_UNAVAILABLE android android-sdk-missing"
      exit 3
    fi
    ;;
  web)
    ;;
  *) echo "unsupported target: $TARGET" >&2; exit 2 ;;
esac
echo "F15_TARGET_AVAILABLE $TARGET"
