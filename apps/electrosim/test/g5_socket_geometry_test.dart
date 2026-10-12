import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final ac in [false, true]) {
    test(
      '${ac ? "AC" : "DC"} native socket keeps all old contact coordinates and saved size',
      () {
        final type = ac ? 'power_socket_ac' : 'power_socket_dc';
        final spec = NativeApplianceGeometry.forVisual(type, null)!;
        final expected = ac
            ? const [
                Offset(-.24, -.4),
                Offset(0, -.4),
                Offset(.24, -.4),
                Offset(-.18, .15),
                Offset(.18, .15),
                Offset(0, -.05),
              ]
            : const [
                Offset(-.12, -.4),
                Offset(.12, -.4),
                Offset(-.12, .25),
                Offset(.12, .25),
              ];
        expect(spec.boardSize, const Size(120, 120));
        for (final size in [const Size(120, 120), const Size(180, 145)]) {
          final offsets = spec.offsets(size, expected.length);
          for (var i = 0; i < expected.length; i++) {
            expect(offsets[i].dx, closeTo(expected[i].dx * size.width, 1e-10));
            expect(offsets[i].dy, closeTo(expected[i].dy * size.height, 1e-10));
          }
        }
      },
    );
  }
}
