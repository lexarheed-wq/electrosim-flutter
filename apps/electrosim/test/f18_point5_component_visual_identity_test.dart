import 'dart:io';

import 'package:electrosim/f18_component_archetypes.dart';
import 'package:electrosim/f18_industrial_component_visuals.dart';
import 'package:electrosim/f9_component_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('V1 parity Point 5 component visual identity', () {
    test('canonical identity keeps one aspect ratio inside arbitrary bounds', () {
      const Rect bounds = Rect.fromLTWH(0, 0, 200, 100);
      final Rect fitted = F18ComponentIdentityMetrics.fit(bounds);
      expect(fitted.width / fitted.height,
          closeTo(F18ComponentIdentityMetrics.aspectRatio, 0.0001));
      expect(fitted.left, greaterThanOrEqualTo(bounds.left));
      expect(fitted.top, greaterThanOrEqualTo(bounds.top));
      expect(fitted.right, lessThanOrEqualTo(bounds.right));
      expect(fitted.bottom, lessThanOrEqualTo(bounds.bottom));
    });

    testWidgets('every palette model uses the canonical identity widget',
        (WidgetTester tester) async {
      for (final F9PaletteDefinition item in f9PaletteCatalog) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: F9ComponentPreview(
                definition: item,
                compact: true,
              ),
            ),
          ),
        );
        await tester.pump();

        final Finder finder = find.byType(F18ComponentIdentityVisual);
        expect(finder, findsOneWidget, reason: item.modelType);
        final F18ComponentIdentityVisual visual =
            tester.widget<F18ComponentIdentityVisual>(finder);
        expect(visual.modelType, item.modelType);
        expect(visual.size, F18ComponentIdentityMetrics.paletteSize);
        expect(tester.takeException(), isNull, reason: item.modelType);
      }
    });

    test('palette drag and board overlay share the exact renderer entry point',
        () {
      final String palette =
          File('lib/f9_component_palette.dart').readAsStringSync();
      final String board =
          File('lib/f9_component_visuals.dart').readAsStringSync();

      expect(palette, contains('F18ComponentIdentityVisual'));
      expect(palette, isNot(contains('class _TerminalDot')));
      expect(
        board,
        contains('paintF18ComponentIdentity'),
      );
      expect(
        board,
        isNot(contains('paintF18ElectricalArchetype(')),
      );
    });

    test('every production palette model has a dedicated industrial renderer', () {
      for (final F9PaletteDefinition item in f9PaletteCatalog) {
        expect(
          isF18IndustrialV2Model(item.modelType),
          isTrue,
          reason: '${item.title} (${item.modelType}) must never fall back to a schematic glyph',
        );
      }
    });

    test('quick catalog has no duplicate visual identity model type', () {
      final Set<String> keyNames = <String>{};
      for (final F9PaletteDefinition item in f9PaletteCatalog) {
        expect(keyNames.add(item.keyName), isTrue, reason: item.keyName);
        expect(item.modelType.trim(), item.modelType);
        expect(item.modelType, isNotEmpty);
      }
    });
  });
}
