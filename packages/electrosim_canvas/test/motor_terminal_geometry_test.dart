import 'dart:ui';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('six motor terminals occupy a single accessible terminal box', () {
    final p = SixTerminalMotorGeometry.offsets(const Size(750, 430));
    expect(p, hasLength(6));
    // Logical order stays U1,V1,W1,U2,V2,W2. Physical bottom row is W2,U2,V2.
    expect(p[0].dy, p[2].dy);
    expect(p[3].dy, p[5].dy);
    expect(
      p.every((v) => v.dx < 0),
      isTrue,
      reason: 'All studs must sit on the small flank box, not above the motor',
    );
    expect(p[3].dy, greaterThan(0));
    expect(p[0].dy, greaterThan(-240 * .15));
    expect(p[5].dx, p[0].dx);
    expect(p[3].dx, p[1].dx);
    expect(p[4].dx, p[2].dx);
    expect((p[0] - p[1]).distance, greaterThan(40));
    final box = Rect.fromLTWH(750 * .225, 430 * .34, 750 * .23, 430 * .28);
    for (final point in p) {
      expect(
        box.contains(const Size(750, 430).center(Offset.zero) + point),
        isTrue,
      );
    }
    expect(box.width / 750, lessThan(.25));
    expect((p[0] - p[5]).distance, greaterThan(30));
  });
}
