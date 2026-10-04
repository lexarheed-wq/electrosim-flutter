import 'dart:io';

import 'package:electrosim/f18_component_asset_visual.dart';
import 'package:electrosim/f9_component_palette.dart';
import 'package:electrosim/reference_components/reference_widgets.dart';
import 'package:electrosim/reference_components/reference_widgets_extended.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Reference component production integration', () {
    testWidgets('every palette model uses the reference wrapper and size contract',
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

        final Finder finder = find.byType(F18ComponentAssetVisual);
        expect(finder, findsOneWidget, reason: item.modelType);
        final F18ComponentAssetVisual visual =
            tester.widget<F18ComponentAssetVisual>(finder);
        expect(visual.modelType, item.modelType);
        expect(
          visual.size,
          F18ReferenceComponentMetrics.paletteSizeFor(item.modelType),
          reason: item.modelType,
        );
        expect(tester.takeException(), isNull, reason: item.modelType);
      }
    });

    testWidgets('uploaded five render through uploaded ReferenceComponentView',
        (WidgetTester tester) async {
      const List<String> models = <String>[
        'dc_voltage_source',
        'switch',
        'lamp',
        'breaker_dc',
        'push_button_no',
      ];
      for (final String modelType in models) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: F18ComponentAssetVisual(
                modelType: modelType,
                size: F18ReferenceComponentMetrics.dragSizeFor(modelType),
                energized: modelType == 'dc_voltage_source' || modelType == 'lamp',
                currentA: .5,
                voltageV: 24,
                closed: modelType == 'switch' || modelType == 'breaker_dc',
                pressed: modelType == 'push_button_no',
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(ReferenceComponentView), findsOneWidget,
            reason: modelType);
        expect(find.byType(ExtendedReferenceComponentView), findsNothing,
            reason: modelType);
        expect(tester.takeException(), isNull, reason: modelType);
      }
    });

    testWidgets('eight additional models use dedicated extended vector painters',
        (WidgetTester tester) async {
      const List<String> models = <String>[
        'resistor',
        'push_button_nc',
        'buzzer',
        'fuse_dc',
        'diode',
        'fan_dc',
        'motor_dc',
        'relay_coil',
      ];
      for (final String modelType in models) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: F18ComponentAssetVisual(
                modelType: modelType,
                size: F18ReferenceComponentMetrics.dragSizeFor(modelType),
                energized: true,
                currentA: .5,
                voltageV: 24,
                resistanceOhm: 100,
                animationValue: .25,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(ExtendedReferenceComponentView), findsOneWidget,
            reason: modelType);
        expect(tester.takeException(), isNull, reason: modelType);
      }
    });

    test('production palette is fully covered by the reference renderer', () {
      for (final F9PaletteDefinition item in f9PaletteCatalog) {
        expect(
          F18ReferenceComponentVisuals.supports(item.modelType),
          isTrue,
          reason: '${item.title} (${item.modelType})',
        );
      }
    });

    test('physical terminal anchors match the reference Dart painter coordinates',
        () {
      const Map<String, double> expectedFractions = <String, double>{
        'dc_voltage_source': .455,
        'switch': .455,
        'lamp': .455,
        'breaker_dc': .455,
        'push_button_no': .455,
        'resistor': .4714285714,
        'push_button_nc': .4444444444,
        'buzzer': .4473684211,
        'fuse_dc': .4733333333,
        'diode': .4703703704,
        'fan_dc': .4523809524,
        'motor_dc': .4565217391,
        'relay_coil': .4473684211,
      };

      for (final MapEntry<String, double> entry in expectedFractions.entries) {
        final Size size = F18ReferenceComponentMetrics.boardSizeFor(entry.key);
        expect(
          TerminalVisualProfile.horizontalHalfSpanForModel(
            entry.key,
            size: size,
          ),
          closeTo(size.width * entry.value, 1e-6),
          reason: entry.key,
        );
      }
    });

    test('renderer remains vector-only and front-view', () {
      for (final String path in <String>[
        'lib/reference_components/reference_widgets.dart',
        'lib/reference_components/reference_widgets_extended.dart',
      ]) {
        final String painter = File(path).readAsStringSync();
        for (final String forbidden in <String>[
          'Image.asset(',
          'DecorationImage(',
          'Matrix4.',
          'rotateX(',
          'rotateY(',
          'skewX(',
          'skewY(',
        ]) {
          expect(
            painter,
            isNot(contains(forbidden)),
            reason: '$path forbids $forbidden',
          );
        }
      }
    });

    test('board uses reference widgets and live runtime animation', () {
      final String board =
          File('lib/f9_component_visuals.dart').readAsStringSync();
      expect(board, contains('F18ReferenceComponentVisuals.supports'));
      expect(board, contains('_paintLiveWires'));
      expect(board, contains('_paintMovingDashes'));
      expect(board, contains('runtimeSnapshot'));
      expect(board, contains('simulationRunning'));
      expect(board, contains('animationValue: _motion.value'));
      expect(board, contains('currentA: currentA'));
      expect(board, contains('voltageV: voltageV'));
    });

    test('no photographic renderer is used by the shared production wrapper', () {
      final String wrapper =
          File('lib/f18_component_asset_visual.dart').readAsStringSync();
      expect(wrapper, contains('ReferenceComponentView'));
      expect(wrapper, contains('ExtendedReferenceComponentView'));
      expect(wrapper, isNot(contains('Image.asset(')));
    });

    test('quick catalog has no duplicate component identity key', () {
      final Set<String> keyNames = <String>{};
      for (final F9PaletteDefinition item in f9PaletteCatalog) {
        expect(keyNames.add(item.keyName), isTrue, reason: item.keyName);
        expect(item.modelType.trim(), item.modelType);
        expect(item.modelType, isNotEmpty);
      }
    });
  });
}
