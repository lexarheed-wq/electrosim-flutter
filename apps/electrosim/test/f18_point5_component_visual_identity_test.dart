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
    testWidgets(
      'every palette model uses the reference wrapper and size contract',
      (WidgetTester tester) async {
        for (final F9PaletteDefinition item in f9PaletteCatalog) {
          await tester.pumpWidget(
            MaterialApp(
              home: Center(
                child: F9ComponentPreview(definition: item, compact: true),
              ),
            ),
          );
          await tester.pump();

          if (item.kind == F9PaletteElementKind.instrument) {
            expect(find.byType(F18PhysicalInstrumentPreview), findsOneWidget);
            expect(find.byType(F18ComponentAssetVisual), findsNothing);
            expect(tester.takeException(), isNull);
            continue;
          }
          final Finder finder = find.byType(F18ComponentAssetVisual);
          expect(finder, findsOneWidget, reason: item.modelType);
          final F18ComponentAssetVisual visual = tester
              .widget<F18ComponentAssetVisual>(finder);
          expect(visual.modelType, item.renderedModelType);
          expect(
            visual.size,
            F18ReferenceComponentMetrics.paletteSizeFor(item.renderedModelType),
            reason: item.renderedModelType,
          );
          expect(tester.takeException(), isNull, reason: item.modelType);
        }
      },
    );

    testWidgets(
      'uploaded five render through uploaded ReferenceComponentView',
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
                  energized:
                      modelType == 'dc_voltage_source' || modelType == 'lamp',
                  currentA: .5,
                  voltageV: 24,
                  closed: modelType == 'switch' || modelType == 'breaker_dc',
                  pressed: modelType == 'push_button_no',
                ),
              ),
            ),
          );
          await tester.pump();

          expect(
            find.byType(ReferenceComponentView),
            findsOneWidget,
            reason: modelType,
          );
          expect(
            find.byType(ExtendedReferenceComponentView),
            findsNothing,
            reason: modelType,
          );
          expect(tester.takeException(), isNull, reason: modelType);
        }
      },
    );

    testWidgets(
      'eight additional models use dedicated extended vector painters',
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

          expect(
            find.byType(ExtendedReferenceComponentView),
            findsOneWidget,
            reason: modelType,
          );
          expect(tester.takeException(), isNull, reason: modelType);
        }
      },
    );

    test('production palette is fully covered by the reference renderer', () {
      for (final F9PaletteDefinition item in f9PaletteCatalog) {
        if (item.kind == F9PaletteElementKind.instrument) {
          expect(item.modelType.startsWith('physical_'), isTrue);
          expect(item.terminalCount, 0);
        } else {
          expect(
            F18ReferenceComponentVisuals.supports(item.renderedModelType),
            isTrue,
            reason:
                '${item.title} (${item.modelType} → ${item.renderedModelType})',
          );
        }
      }
    });

    test('uploaded V2 five keep their exact native production sizes', () {
      expect(
        F18ReferenceComponentMetrics.boardSizeFor('dc_voltage_source'),
        const Size(140, 160),
      );
      expect(
        F18ReferenceComponentMetrics.boardSizeFor('breaker_dc'),
        const Size(72, 160),
      );
      expect(
        F18ReferenceComponentMetrics.boardSizeFor('switch'),
        const Size(90, 140),
      );
      expect(
        F18ReferenceComponentMetrics.boardSizeFor('push_button_no'),
        const Size(90, 140),
      );
      expect(
        F18ReferenceComponentMetrics.boardSizeFor('lamp'),
        const Size(130, 160),
      );
    });

    test('uploaded V2 physical anchors match the exact Dart geometry', () {
      void expectOffset(
        Offset actual,
        Offset expected, {
        required String reason,
      }) {
        expect((actual - expected).distance, lessThan(1e-6), reason: reason);
      }

      expectOffset(
        TerminalVisualProfile.terminalOffset(
          modelType: 'dc_voltage_source',
          size: const Size(140, 160),
          index: 0,
          count: 2,
        ),
        const Offset(-28, 47),
        reason: 'supply terminal 0',
      );
      expectOffset(
        TerminalVisualProfile.terminalOffset(
          modelType: 'breaker_dc',
          size: const Size(72, 160),
          index: 0,
          count: 2,
        ),
        const Offset(0, -57),
        reason: 'breaker terminal 0',
      );
      expectOffset(
        TerminalVisualProfile.terminalOffset(
          modelType: 'switch',
          size: const Size(90, 140),
          index: 1,
          count: 2,
        ),
        const Offset(0, 50),
        reason: 'switch terminal 1',
      );
      expectOffset(
        TerminalVisualProfile.terminalOffset(
          modelType: 'push_button_no',
          size: const Size(90, 140),
          index: 0,
          count: 2,
        ),
        const Offset(-14, 49),
        reason: 'button terminal 0',
      );
      expectOffset(
        TerminalVisualProfile.terminalOffset(
          modelType: 'lamp',
          size: const Size(130, 160),
          index: 1,
          count: 2,
        ),
        const Offset(25, 59),
        reason: 'lamp terminal 1',
      );
    });

    test('direct-control hit zones stay on the physical actuator only', () {
      expect(
        ReferenceComponentView.hitsControlRegion(
          const Size(90, 140),
          const Offset(45, 60),
          device: ReferenceDevice.button,
        ),
        isTrue,
      );
      expect(
        ReferenceComponentView.hitsControlRegion(
          const Size(90, 140),
          const Offset(8, 8),
          device: ReferenceDevice.button,
        ),
        isFalse,
      );
      expect(
        ReferenceComponentView.hitsControlRegion(
          const Size(90, 140),
          const Offset(45, 70),
          device: ReferenceDevice.toggle,
        ),
        isTrue,
      );
      expect(
        ReferenceComponentView.hitsControlRegion(
          const Size(72, 160),
          const Offset(36, 84),
          device: ReferenceDevice.breaker,
        ),
        isTrue,
      );
      expect(
        ReferenceComponentView.hitsControlRegion(
          const Size(140, 160),
          const Offset(70, 80),
          device: ReferenceDevice.supply,
        ),
        isFalse,
      );
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
      final String board = File(
        'lib/f9_component_visuals.dart',
      ).readAsStringSync();
      expect(board, contains('F18ReferenceComponentVisuals.supports'));
      expect(board, contains('_F9CurrentFlowPainter'));
      expect(board, contains('super(repaint: motionSeconds)'));
      expect(board, contains('_paintMovingDashes'));
      expect(board, contains('elapsedSeconds: motionSeconds.value'));
      expect(board, contains('runtimeSnapshot'));
      expect(board, contains('simulationRunning'));
      expect(board, contains('motionSeconds: _motionSeconds'));
      expect(board, contains('currentA: currentA'));
      expect(board, contains('voltageV: voltageV'));
    });

    test(
      'no photographic renderer is used by the shared production wrapper',
      () {
        final String wrapper = File(
          'lib/f18_component_asset_visual.dart',
        ).readAsStringSync();
        expect(wrapper, contains('ReferenceComponentView'));
        expect(wrapper, contains('ExtendedReferenceComponentView'));
        expect(wrapper, isNot(contains('Image.asset(')));
      },
    );

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
