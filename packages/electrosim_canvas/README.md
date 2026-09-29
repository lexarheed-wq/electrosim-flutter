# electrosim_canvas — F8

Flutter-only rendering and interaction layer for ElectroSim.

Rules:

- consumes immutable `CircuitState` and separate graphical layout data;
- never computes voltage, current, power, topology or device operating state;
- centralizes hit-testing;
- click selects without moving;
- long-press + drag requests a graphical move through a callback;
- terminal-to-terminal gestures request a connection through a callback;
- pan and zoom affect only the viewport;
- double-click/tap emits a contextual hit action;
- CircuitState is never mutated by the Canvas.

## Toolchain input API imports

Pointer signal, scroll, hover and device-kind APIs are imported explicitly from `package:flutter/gestures.dart` so the package remains analyzable on the locked Flutter 3.38.10 / Dart 3.10.9 Monterey toolchain.
