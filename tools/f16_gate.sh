#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKG="$ROOT/packages/electrosim_scenarios"

cd "$PKG"
dart pub get
dart analyze
dart test test/example_repository_test.dart
dart test test/fault_scenario_repository_test.dart
dart test test/f16_catalog_test.dart

printf 'F16_GATE_PASS\n'
