import 'dart:ui' show Rect;
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rounding keeps endpoints and bounds without editing saved routes', () {
    const points = [Offset(10, 10), Offset(110, 10), Offset(110, 90)];
    final path = buildPhysicalWirePath(points, bendRadius: 8);
    final metric = path.computeMetrics().single;
    expect(metric.getTangentForOffset(0)!.position, points.first);
    expect(
      (metric.getTangentForOffset(metric.length)!.position - points.last)
          .distance,
      lessThan(.001),
    );
    expect(path.getBounds(), const Rect.fromLTRB(10, 10, 110, 90));
    expect(metric.length, lessThan(180));
    expect(metric.length, greaterThan(170));
    expect(points[1], const Offset(110, 10));
  });

  test('short segments and duplicate points remain finite', () {
    final path = buildPhysicalWirePath(const [
      Offset.zero,
      Offset(2, 0),
      Offset(2, 0),
      Offset(2, 2),
    ], bendRadius: 20);
    expect(path.computeMetrics().single.length.isFinite, isTrue);
    expect(path.getBounds(), const Rect.fromLTWH(0, 0, 2, 2));
  });

  test('a reversal keeps its full route length', () {
    final path = buildPhysicalWirePath(const [
      Offset.zero,
      Offset(10, 0),
      Offset.zero,
    ]);
    expect(path.computeMetrics().single.length, 20);
  });
}
