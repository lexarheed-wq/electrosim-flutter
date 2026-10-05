import 'package:electrosim/f18_component_archetypes.dart';
import 'package:electrosim/f9_component_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('M11 every production palette model paints without exception', (
    WidgetTester tester,
  ) async {
    for (final F9PaletteDefinition item in f9PaletteCatalog) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: F18ComponentArchetypeGlyph(
              modelType: item.modelType,
              size: 40,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: item.modelType);
    }
  });

  test('M11 canonical protection models keep the protection archetype', () {
    expect(
      F18ElectricalArchetypeClassifier.forModel('breaker_dc'),
      F18ElectricalArchetype.protection,
    );
    expect(
      F18ElectricalArchetypeClassifier.forModel('fuse_dc'),
      F18ElectricalArchetype.protection,
    );
  });
}
