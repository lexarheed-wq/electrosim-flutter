# CI intent (F0)

Required base gate when Flutter SDK is available:

1. `dart format --output=none --set-exit-if-changed .`
2. `flutter analyze`
3. `flutter test`
4. `python3 tools/f0_guard.py`

F0 must remain blocked if any step fails.
