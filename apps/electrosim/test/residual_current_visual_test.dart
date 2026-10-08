import 'package:electrosim/professional_residual_current_visual.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('differential terminals remain inside the top and bottom decks', () {
    for (final poles in [2, 4]) {
      final points = ResidualCurrentVisual.terminalOffsets(
        const Size(108, 180),
        poles: poles,
      );
      expect(points, hasLength(poles * 2));
      expect(points.take(poles).every((p) => p.dy < 0), isTrue);
      expect(points.skip(poles).every((p) => p.dy > 0), isTrue);
      expect(points.every((p) => p.dx.abs() < 54 && p.dy.abs() < 90), isTrue);
    }
  });
  testWidgets(
    'visual-only differential makes no claim to simulate protection',
    (t) async {
      final semantics = t.ensureSemantics();
      await t.pumpWidget(
        const MaterialApp(home: Center(child: ResidualCurrentVisual())),
      );
      expect(find.bySemanticsLabel(RegExp('.*rendu visuel.*')), findsOneWidget);
      expect(t.takeException(), isNull);
      semantics.dispose();
    },
  );
}
