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
