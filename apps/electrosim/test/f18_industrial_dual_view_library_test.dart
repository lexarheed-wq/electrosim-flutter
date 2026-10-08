import 'package:electrosim/f18_industrial_dual_view.dart';
import 'package:electrosim/f9_component_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dual-view camera is fixed, never a runtime-editable 3D rotation', () {
    expect(F18IndustrialDualView.paletteYawDegrees, 10);
    expect(F18IndustrialDualView.palettePitchDegrees, -12);
    expect(F18IndustrialDualView.boardYawDegrees, 0);
    expect(F18IndustrialDualView.boardPitchDegrees, 0);
    expect(F18IndustrialDualView.paletteCamera().storage[0].isFinite, isTrue);
  });

  test('all catalogue entries resolve to one industrial family', () {
    expect(f9PaletteCatalog.length, greaterThanOrEqualTo(70));
    final Set<String> ids = <String>{};
    for (final item in f9PaletteCatalog) {
      expect(ids.add(item.keyName), isTrue);
      expect(
        F18IndustrialIdentity.familyOf(item.renderedModelType),
        isA<F18IndustrialFamily>(),
        reason: item.keyName,
      );
    }
    expect(
      F18IndustrialIdentity.familyOf('physical_voltmeter'),
      F18IndustrialFamily.instrument,
    );
    expect(
      F18IndustrialIdentity.familyOf('breaker_3p'),
      F18IndustrialFamily.modularProtection,
    );
    expect(
      F18IndustrialIdentity.familyOf('motor_3p_6t'),
      F18IndustrialFamily.drive,
    );
    expect(
      F18IndustrialIdentity.familyOf('pv_array'),
      F18IndustrialFamily.solar,
    );
  });

  testWidgets('board presentation retains the child without transforms', (
    tester,
  ) async {
    const child = Text('canonical board artwork', key: Key('front-art'));
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: F18IndustrialDualView(
          modelType: 'motor_3p_6t',
          size: Size(200, 180),
          presentation: F18IndustrialPresentation.boardFront,
          child: child,
        ),
      ),
    );
    expect(find.byKey(const Key('front-art')), findsOneWidget);
    expect(find.byType(Transform), findsNothing);
  });

  const examples = <String>[
    'source-dc-24v',
    'breaker',
    'switch-no',
    'contactor-3p',
    'thermal-overload-3p',
    'motor-dc',
    'motor-3p-6t',
    'pv-array',
    'pv-controller-mppt',
    'pv-battery',
    'pv-inverter',
    'instrument-voltmeter',
    'instrument-ammeter',
    'terminal-block-5',
    'external-crusher',
    'capacitor',
  ];

  for (final id in examples) {
    testWidgets('$id renders as a three-quarter palette identity', (
      tester,
    ) async {
      final definition = f9PaletteCatalog.singleWhere(
        (item) => item.keyName == id,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: F9ComponentPreview(definition: definition)),
          ),
        ),
      );
      await tester.pump();
      final visual = tester.widget<F18IndustrialDualView>(
        find.byType(F18IndustrialDualView),
      );
      expect(visual.presentation, F18IndustrialPresentation.palettePerspective);
      expect(visual.modelType, definition.renderedModelType);
      expect(find.byType(Transform), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
