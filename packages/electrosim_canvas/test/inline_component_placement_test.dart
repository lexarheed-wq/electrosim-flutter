import 'dart:ui';

import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const InlinePlacementPolicy policy = InlinePlacementPolicy(
    grid: 24,
    bendKeepOut: 48,
    minimumTerminalStub: 24,
    minimumComponentGap: 48,
  );

  test('single component is centered on a straight host segment', () {
    const OrthogonalSegment host = OrthogonalSegment(
      start: Offset(0, 120),
      end: Offset(288, 120),
    );

    final InlinePlacementResult result = policy.placeCentered(
      host: host,
      componentExtents: const <double>[48],
    );

    expect(result.isResolved, isTrue);
    expect(result.centers, const <Offset>[Offset(144, 120)]);
  });

  test('two components are placed symmetrically around branch midpoint', () {
    const OrthogonalSegment host = OrthogonalSegment(
      start: Offset(0, 120),
      end: Offset(384, 120),
    );

    final InlinePlacementResult result = policy.placeCentered(
      host: host,
      componentExtents: const <double>[48, 48],
    );

    expect(result.isResolved, isTrue);
    expect(result.centers, hasLength(2));
    expect(result.centers[0].dy, 120);
    expect(result.centers[1].dy, 120);
    expect(result.centers[0].dx + result.centers[1].dx, 384);
    expect(result.centers[1].dx - result.centers[0].dx, greaterThanOrEqualTo(96));
  });

  test('placement refuses a segment that cannot respect bend keep-out', () {
    const OrthogonalSegment host = OrthogonalSegment(
      start: Offset(0, 120),
      end: Offset(120, 120),
    );

    final InlinePlacementResult result = policy.placeCentered(
      host: host,
      componentExtents: const <double>[48],
    );

    expect(result.isResolved, isFalse);
    expect(result.centers, isEmpty);
    expect(result.reason, InlinePlacementFailure.insufficientStraightLength);
  });

  test('vertical placement stays collinear with the host', () {
    const OrthogonalSegment host = OrthogonalSegment(
      start: Offset(120, 0),
      end: Offset(120, 288),
    );

    final InlinePlacementResult result = policy.placeCentered(
      host: host,
      componentExtents: const <double>[48],
    );

    expect(result.isResolved, isTrue);
    expect(result.centers.single, const Offset(120, 144));
  });
}
