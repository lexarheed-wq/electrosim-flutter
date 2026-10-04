import 'dart:io';

import 'package:electrosim/f18_component_archetypes.dart';
import 'package:electrosim/f18_component_asset_visual.dart';
import 'package:electrosim/f18_industrial_component_visuals.dart';
import 'package:electrosim/f18_v1_component_visuals.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim/f9_component_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('V1 parity Point 5 component visual identity', () {
    test('canonical identity keeps one aspect ratio inside arbitrary bounds', () {
      const Rect bounds = Rect.fromLTWH(0, 0, 200, 100);
      final Rect fitted = F18ComponentIdentityMetrics.fit(bounds);
      expect(
        fitted.width / fitted.height,
        closeTo(F18ComponentIdentityMetrics.aspectRatio, 0.0001),
      );
      expect(fitted.left, greaterThanOrEqualTo(bounds.left));
      expect(fitted.top, greaterThanOrEqualTo(bounds.top));
      expect(fitted.right, lessThanOrEqualTo(bounds.right));
      expect(fitted.bottom, lessThanOrEqualTo(bounds.bottom));
    });

    testWidgets('every palette model uses the canonical shared wrapper',
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
        expect(visual.size, F18ComponentIdentityMetrics.paletteSize);
        expect(tester.takeException(), isNull, reason: item.modelType);
      }
    });

    testWidgets('five pilot families render with the V1 native painter',
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
                size: F18ComponentIdentityMetrics.dragSize,
                energized: modelType == 'dc_voltage_source' || modelType == 'lamp',
                closed: modelType == 'switch' || modelType == 'breaker_dc',
                pressed: modelType == 'push_button_no',
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          find.byType(F18V1ComponentVisual),
          findsOneWidget,
          reason: modelType,
        );
        expect(tester.takeException(), isNull, reason: modelType);
      }
    });

    test('pilot coverage is exactly the requested five component families', () {
      const Set<String> expected = <String>{
        'dc_voltage_source',
        'switch',
        'lamp',
        'breaker_dc',
        'push_button_no',
      };
      for (final String modelType in expected) {
        expect(
          F18V1PilotVisuals.supports(modelType),
          isTrue,
          reason: modelType,
        );
      }
      expect(
        F18V1PilotVisuals.supports('resistor'),
        isFalse,
        reason: 'The first pilot must stop after five component families.',
      );
    });

    test('pilot terminal spans are physical and model-specific', () {
      const Size designSize = Size(104, 64);
      const Map<String, double> expected = <String, double>{
        'dc_voltage_source': 46.0,
        'switch': 31.2,
        'lamp': 27.0,
        'breaker_dc': 37.2,
        'push_button_no': 31.2,
      };
      for (final MapEntry<String, double> entry in expected.entries) {
        expect(
          TerminalVisualProfile.horizontalHalfSpanForModel(
            entry.key,
            size: designSize,
          ),
          closeTo(entry.value, 0.0001),
          reason: entry.key,
        );
        expect(entry.value, lessThan(designSize.width / 2));
      }
    });

    test('physical nodes remain distinct from invisible routing ports', () {
      const Size designSize = Size(104, 64);
      final Offset visible = TerminalVisualProfile.terminalOffset(
        modelType: 'switch',
        size: designSize,
        index: 1,
        count: 2,
      );
      final Offset routing = TerminalVisualProfile.routingOffset(
        size: designSize,
        index: 1,
        count: 2,
      );

      expect(visible.dx, closeTo(31.2, 0.0001));
      expect(routing, const Offset(52, 0));
      expect(visible.dx, lessThan(routing.dx));
    });

    test('Point 5D contract is front-view vector only', () {
      expect(F18V1PilotVisuals.renderingMode, 'free_silhouette_front_vector');
      expect(F18V1PilotVisuals.frontViewOnly, isTrue);
      expect(F18V1PilotVisuals.rasterAssetsAllowed, isFalse);
      expect(F18V1PilotVisuals.perspectiveAllowed, isFalse);

      final String painter =
          File('lib/f18_v1_component_visuals.dart').readAsStringSync();
      for (final String forbidden in <String>[
        'Image.asset(',
        'DecorationImage(',
        'Matrix4.',
        'setEntry(3, 2',
        'rotateX(',
        'rotateY(',
        'skewX(',
        'skewY(',
      ]) {
        expect(
          painter,
          isNot(contains(forbidden)),
          reason: 'Front-view vector contract forbids $forbidden',
        );
      }
    });

    test('Point 5D-R2 uses free real silhouettes, never a visible generic box', () {
      expect(F18V1PilotVisuals.renderingMode, 'free_silhouette_front_vector');
      expect(F18V1PilotVisuals.visibleBoundingBoxAllowed, isFalse);

      const Map<String, String> expected = <String, String>{
        'dc_voltage_source': 'industrial_power_supply_front',
        'switch': 'rocker_switch_front',
        'push_button_no': 'round_pushbutton_front',
        'breaker_dc': 'stepped_mcb_front',
        'lamp': 'round_pilot_lamp_front',
      };
      for (final MapEntry<String, String> entry in expected.entries) {
        expect(
          F18V1PilotVisuals.silhouetteByModel[entry.key],
          entry.value,
          reason: entry.key,
        );
        expect(entry.value, isNot(contains('generic_box')));
      }

      final String painter =
          File('lib/f18_v1_component_visuals.dart').readAsStringSync();
      expect(painter, contains('Circular front only'));
      expect(painter, contains('Only the real circular bezel is visible'));
      expect(painter, contains('A stepped MCB outline'));
      expect(painter, isNot(contains('generic visible component box')));
    });

    test('generated raster assets are no longer the runtime renderer', () {
      final String wrapper =
          File('lib/f18_component_asset_visual.dart').readAsStringSync();
      expect(wrapper, contains('F18V1ComponentVisual'));
      expect(wrapper, isNot(contains('Image.asset(')));
    });

    test('board owns V1 visuals crisp terminals and current-flow animation', () {
      final String board =
          File('lib/f9_component_visuals.dart').readAsStringSync();
      expect(board, contains('F18V1PilotVisuals.supports'));
      expect(board, contains('_paintTerminals'));
      expect(board, contains('_paintLiveWires'));
      expect(board, contains('_paintMovingDashes'));
      expect(board, contains('runtimeSnapshot'));
      expect(board, contains('simulationRunning'));
      expect(board, contains('paintF18ComponentIdentity'));
      expect(
        board,
        isNot(contains('paintF18ElectricalArchetype(')),
      );
    });

    test('every non-pilot production model retains a local vector fallback', () {
      for (final F9PaletteDefinition item in f9PaletteCatalog) {
        if (F18V1PilotVisuals.supports(item.modelType)) continue;
        expect(
          isF18IndustrialV2Model(item.modelType),
          isTrue,
          reason:
              '${item.title} (${item.modelType}) must retain a local vector fallback',
        );
      }
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
