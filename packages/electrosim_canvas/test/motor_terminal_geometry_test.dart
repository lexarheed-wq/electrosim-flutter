import 'dart:ui';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('six motor terminals occupy a single accessible terminal box', () {
    final p = SixTerminalMotorGeometry.offsets(const Size(260, 240));
    expect(p, hasLength(6));
    // Logical order stays U1,V1,W1,U2,V2,W2. Physical bottom row is W2,U2,V2.
    expect(p[0].dy, p[2].dy);
    expect(p[3].dy, p[5].dy);
    expect(p.every((v) => v.dy < 0), isTrue);
    expect(p[5].dx, p[0].dx);
    expect(p[3].dx, p[1].dx);
    expect(p[4].dx, p[2].dx);
    expect((p[0] - p[1]).distance, greaterThan(40));
    expect((p[0] - p[5]).distance, greaterThan(30));
  });
}
