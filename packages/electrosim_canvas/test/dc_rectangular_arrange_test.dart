import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const DcRectangularArrangePolicy policy = DcRectangularArrangePolicy(
    grid: 24,
    bendKeepOut: 48,
    minimumTerminalStub: 24,
    minimumComponentGap: 48,
  );

  test('simple DC loop places source and load at vertical midpoints', () {
    final DcRectangularArrangement result = policy.arrange(
      topLeft: const Offset(48, 48),
      width: 480,
      height: 288,
      sourceId: 'G1',
      loadId: 'H1',
      topInlineElements: const <DcInlineElement>[
        DcInlineElement(id: 'QF1', extent: 72),
        DcInlineElement(id: 'S1', extent: 72),
      ],
    );

    expect(result.isResolved, isTrue);
    expect(result.positions['G1'], const Offset(48, 192));
    expect(result.positions['H1'], const Offset(528, 192));
    expect(result.positions['QF1']!.dy, 48);
    expect(result.positions['S1']!.dy, 48);
  });

  test('series devices are symmetric around the top branch midpoint', () {
    final DcRectangularArrangement result = policy.arrange(
      topLeft: const Offset(48, 48),
      width: 480,
      height: 288,
      sourceId: 'G1',
      loadId: 'H1',
      topInlineElements: const <DcInlineElement>[
        DcInlineElement(id: 'QF1', extent: 72),
        DcInlineElement(id: 'S1', extent: 72),
      ],
    );

    final double midpointX = 48 + 480 / 2;
    final double leftDistance = midpointX - result.positions['QF1']!.dx;
    final double rightDistance = result.positions['S1']!.dx - midpointX;
    expect(leftDistance, rightDistance);
  });

  test('inline devices stay outside bend keep-out zones', () {
    final DcRectangularArrangement result = policy.arrange(
      topLeft: const Offset(48, 48),
      width: 480,
      height: 288,
      sourceId: 'G1',
      loadId: 'H1',
      topInlineElements: const <DcInlineElement>[
        DcInlineElement(id: 'QF1', extent: 72),
        DcInlineElement(id: 'S1', extent: 72),
      ],
    );

    for (final DcInlineElement element in const <DcInlineElement>[
      DcInlineElement(id: 'QF1', extent: 72),
      DcInlineElement(id: 'S1', extent: 72),
    ]) {
      final double x = result.positions[element.id]!.dx;
      expect(x - element.extent / 2, greaterThanOrEqualTo(48 + 48 + 24));
      expect(x + element.extent / 2, lessThanOrEqualTo(528 - 48 - 24));
    }
  });

  test('undersized rectangle returns unresolved instead of placing on bends', () {
    final DcRectangularArrangement result = policy.arrange(
      topLeft: const Offset(48, 48),
      width: 240,
      height: 192,
      sourceId: 'G1',
      loadId: 'H1',
      topInlineElements: const <DcInlineElement>[
        DcInlineElement(id: 'QF1', extent: 72),
        DcInlineElement(id: 'S1', extent: 72),
      ],
    );

    expect(result.isResolved, isFalse);
    expect(
      result.failure,
      DcArrangeFailure.insufficientStraightBranchLength,
    );
  });
}
