import 'package:electrosim/f14_library_components.dart';
import 'package:electrosim/f18_component_asset_visual.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('NO and NC push buttons share the same narrow front footprint', () {
    expect(
      F18ReferenceComponentMetrics.boardSizeFor('push_button_nc'),
      F18ReferenceComponentMetrics.boardSizeFor('push_button_no'),
    );
  });
  test('DIN contactors and breakers use slender front-view proportions', () {
    for (final model in ['contactor_ac1', 'contactor_3p', 'breaker_3p']) {
      final size = F18ReferenceComponentMetrics.boardSizeFor(model);
      expect(size.width / size.height, lessThan(.72), reason: model);
    }
  });

  test('all six motor studs coincide with their interactive anchors', () {
    final size = F18ReferenceComponentMetrics.boardSizeFor('motor_3p_6t');
    final studs = SixTerminalMotorGeometry.offsets(size);
    for (var i = 0; i < 6; i++) {
      expect(
        TerminalVisualProfile.terminalOffset(
          modelType: 'motor_3p_6t',
          size: size,
          index: i,
          count: 6,
        ),
        studs[i],
      );
    }
  });

  testWidgets('contactor state remains supplied by the simulation', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: F18ComponentAssetVisual(
          modelType: 'contactor_3p',
          size: Size(145, 220),
          active: true,
          energized: true,
          closed: true,
        ),
      ),
    );
    final view = t.widget<F14LibraryComponentView>(
      find.byType(F14LibraryComponentView),
    );
    expect(view.state.energized, isTrue);
    expect(t.takeException(), isNull);
  });
}
