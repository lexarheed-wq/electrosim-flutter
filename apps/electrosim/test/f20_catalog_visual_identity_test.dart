import 'package:electrosim/f20_catalog_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('external appliance variants have distinct visual identities', () {
    final Set<F20ApplianceSilhouette> identities = <F20ApplianceSilhouette>{
      F20CatalogVisualIdentity.applianceSilhouette('air-conditioner'),
      F20CatalogVisualIdentity.applianceSilhouette('freezer'),
      F20CatalogVisualIdentity.applianceSilhouette('computer'),
      F20CatalogVisualIdentity.applianceSilhouette('refrigerator'),
      F20CatalogVisualIdentity.applianceSilhouette('refrigerator-dc'),
      F20CatalogVisualIdentity.applianceSilhouette('television'),
    };

    expect(identities.length, 6);
    expect(
      F20CatalogVisualIdentity.applianceSilhouette('unknown'),
      F20ApplianceSilhouette.generic,
    );
  });

  test('motor-driven variants have distinct visual identities', () {
    final Set<F20MotorSilhouette> identities = <F20MotorSilhouette>{
      F20CatalogVisualIdentity.motorSilhouette('pump'),
      F20CatalogVisualIdentity.motorSilhouette('fan'),
      F20CatalogVisualIdentity.motorSilhouette('compressor'),
      F20CatalogVisualIdentity.motorSilhouette('conveyor'),
      F20CatalogVisualIdentity.motorSilhouette('mixer'),
      F20CatalogVisualIdentity.motorSilhouette('crusher'),
    };

    expect(identities.length, 6);
    expect(
      F20CatalogVisualIdentity.motorSilhouette('unknown'),
      F20MotorSilhouette.generic,
    );
  });

  testWidgets('all motor-driven silhouettes render without exception', (
    WidgetTester tester,
  ) async {
    const List<(F20CatalogDevice, String)> cases = <(F20CatalogDevice, String)>[
      (F20CatalogDevice.motorDriven2t, 'pump'),
      (F20CatalogDevice.motorDriven2t, 'fan'),
      (F20CatalogDevice.motorDriven6t, 'pump'),
      (F20CatalogDevice.motorDriven6t, 'fan'),
      (F20CatalogDevice.motorDriven6t, 'compressor'),
      (F20CatalogDevice.motorDriven6t, 'conveyor'),
      (F20CatalogDevice.motorDriven6t, 'mixer'),
      (F20CatalogDevice.motorDriven6t, 'crusher'),
    ];

    for (final (F20CatalogDevice device, String variant) in cases) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: F20CatalogComponentView(
              device: device,
              size: device == F20CatalogDevice.motorDriven6t
                  ? const Size(240, 220)
                  : const Size(210, 180),
              state: F20CatalogState(
                energized: true,
                voltageV: 230,
                currentA: 2,
                animationValue: .37,
                variantKey: variant,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: variant);
    }
  });

  test('iron uses a dedicated heater silhouette', () {
    expect(
      F20CatalogVisualIdentity.heaterSilhouette('iron'),
      F20HeaterSilhouette.iron,
    );
    expect(
      F20CatalogVisualIdentity.heaterSilhouette('unknown'),
      F20HeaterSilhouette.generic,
    );
  });

  testWidgets('iron silhouette renders without exception', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: F20CatalogComponentView(
            device: F20CatalogDevice.heater,
            size: Size(190, 170),
            state: F20CatalogState(
              energized: true,
              voltageV: 230,
              currentA: 5,
              variantKey: 'iron',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('all external appliance silhouettes render without exception', (
    WidgetTester tester,
  ) async {
    const List<String> variants = <String>[
      'air-conditioner',
      'freezer',
      'computer',
      'refrigerator',
      'refrigerator-dc',
      'television',
    ];

    for (final String variant in variants) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: F20CatalogComponentView(
              device: F20CatalogDevice.appliance2t,
              size: const Size(180, 190),
              state: F20CatalogState(
                energized: true,
                voltageV: 230,
                currentA: 2,
                variantKey: variant,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: variant);
    }
  });
}
