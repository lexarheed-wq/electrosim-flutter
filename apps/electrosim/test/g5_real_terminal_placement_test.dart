import 'dart:ui';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('battery anchors coincide with the two top lid posts', () {
    const size = Size(210, 170);
    final ports = List.generate(
      2,
      (i) =>
          size.center(Offset.zero) +
          TerminalVisualProfile.terminalOffset(
            modelType: 'pv_battery',
            size: size,
            index: i,
            count: 2,
          ),
    );
    expect(ports, [const Offset(31.5, 17), const Offset(178.5, 17)]);
  });
  test('controller four electrical ports occupy one lower terminal bank', () {
    const size = Size(200, 200);
    final ports = List.generate(
      4,
      (i) =>
          size.center(Offset.zero) +
          TerminalVisualProfile.terminalOffset(
            modelType: 'pv_controller',
            size: size,
            index: i,
            count: 4,
          ),
    );
    expect(ports, [
      const Offset(58, 176),
      const Offset(86, 176),
      const Offset(114, 176),
      const Offset(142, 176),
    ]);
    // Electrical order remains PV+, PV-, BAT+, BAT-; topology IDs are untouched.
  });
}
