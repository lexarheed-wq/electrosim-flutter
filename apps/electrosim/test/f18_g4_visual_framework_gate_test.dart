import 'package:electrosim/f18_component_archetypes.dart';
import 'package:electrosim/f18_component_asset_visual.dart';
import 'package:electrosim/f9_component_palette.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const List<String> criticalKeys = <String>[
    'source-dc-24v',
    'source-ac1-230v',
    'source-ac3-grid',
    'pv-array',
    'switch-no',
    'push-button-no',
    'push-button-nc',
    'breaker',
    'fuse',
    'resistor',
    'lamp',
    'motor-dc',
    'relay-coil',
    'contactor-ac1',
    'contactor-3p',
    'thermal-overload-3p',
    'motor-3p-6t',
    'terminal-block-5',
    'pv-controller-mppt',
    'pv-inverter',
  ];

  test('G4 has at least twenty qualified critical visual families', () {
    final Map<String, F9PaletteDefinition> byKey =
        <String, F9PaletteDefinition>{
          for (final F9PaletteDefinition item in f9PaletteCatalog)
            item.keyName: item,
        };
    expect(criticalKeys.toSet().length, 20);
    for (final String key in criticalKeys) {
      final F9PaletteDefinition? item = byKey[key];
      expect(item, isNotNull, reason: key);
      expect(
        F18ReferenceComponentVisuals.supports(item!.renderedModelType),
        isTrue,
        reason: '$key -> ${item.renderedModelType}',
      );
      final Size board = F18ReferenceComponentMetrics.boardSizeFor(
        item.renderedModelType,
      );
      expect(board.width, greaterThan(40), reason: key);
      expect(board.height, greaterThan(40), reason: key);
      expect(item.terminalCount, greaterThan(0), reason: key);
    }
  });

  testWidgets(
    'critical families never fall back to generic archetype painter',
    (WidgetTester tester) async {
      final Map<String, F9PaletteDefinition> byKey =
          <String, F9PaletteDefinition>{
            for (final F9PaletteDefinition item in f9PaletteCatalog)
              item.keyName: item,
          };
      for (final String key in criticalKeys) {
        final F9PaletteDefinition item = byKey[key]!;
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: F18ComponentAssetVisual(
                modelType: item.renderedModelType,
                variantKey: item.visualVariant,
                size: F18ReferenceComponentMetrics.dragSizeFor(
                  item.renderedModelType,
                ),
                active: true,
                energized: true,
                currentA: 1,
                voltageV: 24,
                animationValue: .3,
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          find.byType(F18ComponentIdentityVisual),
          findsNothing,
          reason: key,
        );
        expect(tester.takeException(), isNull, reason: key);
      }
    },
  );

  test(
    'palette-to-board identity descriptor is complete and unique per mode',
    () {
      for (final F9PaletteDefinition item in f9PaletteCatalog) {
        expect(item.keyName.trim(), item.keyName);
        expect(item.title.trim(), item.title);
        expect(item.modelType.trim(), item.modelType);
        expect(item.renderedModelType.trim(), item.renderedModelType);
        if (item.kind == F9PaletteElementKind.instrument) {
          expect(item.terminalCount, 0, reason: item.keyName);
          expect(
            item.renderedModelType.startsWith('physical_'),
            isTrue,
            reason: 'Meters must not masquerade as circuit branches.',
          );
          continue;
        }
        expect(item.terminalCount, greaterThan(0), reason: item.keyName);
        expect(
          F18ReferenceComponentVisuals.supports(item.renderedModelType),
          isTrue,
          reason: item.keyName,
        );
      }
    },
  );

  test('rotation contract preserves physical size semantics', () {
    final CircuitVisualLayout layout = CircuitVisualLayout(
      elementPositions: const <String, Offset>{'component': Offset(200, 200)},
      elementSizes: const <String, Size>{'component': Size(90, 140)},
    );
    expect(layout.displaySizeOf('component'), const Size(90, 140));
    final CircuitVisualLayout rotated = layout.rotateElement('component');
    expect(rotated.quarterTurnsOf('component'), 1);
    expect(rotated.displaySizeOf('component'), const Size(140, 90));
  });
}
