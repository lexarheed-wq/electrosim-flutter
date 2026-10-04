import 'package:electrosim/f14_library_components.dart';
import 'package:electrosim/f18_component_asset_visual.dart';
import 'package:electrosim/f9_component_palette.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const Set<String> wave1Models = <String>{
    'capacitor',
    'inductor',
    'impedance',
    'breaker_ac1',
    'fuse_ac1',
    'contactor_aux_no',
    'contactor_aux_nc',
    'contactor_ac1',
    'contactor_3p',
    'breaker_3p',
    'thermal_overload_3p',
  };

  test('C14 wave 1 palette exposes canonical engine model names', () {
    final Map<String, F9PaletteDefinition> byType =
        <String, F9PaletteDefinition>{
      for (final F9PaletteDefinition item in f9PaletteCatalog)
        item.modelType: item,
    };
    expect(byType.keys, containsAll(wave1Models));

    for (final String modelType in wave1Models) {
      final ComponentModelContract? contract =
          CoreComponentModelContracts.registry.resolve(modelType);
      expect(contract, isNotNull, reason: modelType);
      final F9PaletteDefinition definition = byType[modelType]!;
      final int terminalCount = definition.terminals.isNotEmpty
          ? definition.terminals.length
          : definition.terminalLabels.length;
      expect(terminalCount, contract!.terminalCount, reason: modelType);
      expect(
        F18ReferenceComponentVisuals.supports(modelType),
        isTrue,
        reason: modelType,
      );
    }
  });

  testWidgets(
    'C14 vector library painters render through production wrapper',
    (WidgetTester tester) async {
      const List<String> nativeLibraryModels = <String>[
        'capacitor',
        'inductor',
        'impedance',
        'contactor_aux_no',
        'contactor_aux_nc',
        'contactor_ac1',
        'contactor_3p',
        'breaker_3p',
        'thermal_overload_3p',
      ];
      for (final String modelType in nativeLibraryModels) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: F18ComponentAssetVisual(
                modelType: modelType,
                size: F18ReferenceComponentMetrics.dragSizeFor(modelType),
                energized: true,
                currentA: 2.5,
                voltageV: 230,
                actuated: modelType.startsWith('contactor'),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          find.byType(F14LibraryComponentView),
          findsOneWidget,
          reason: modelType,
        );
        expect(tester.takeException(), isNull, reason: modelType);
      }
    },
  );

  test('C14 multipole terminal anchors are unique and physical', () {
    const Map<String, (Size, int)> cases = <String, (Size, int)>{
      'contactor_ac1': (Size(160, 210), 4),
      'contactor_3p': (Size(220, 240), 8),
      'breaker_3p': (Size(190, 220), 6),
      'thermal_overload_3p': (Size(200, 220), 6),
    };

    for (final MapEntry<String, (Size, int)> entry in cases.entries) {
      final Set<Offset> positions = <Offset>{};
      for (var index = 0; index < entry.value.$2; index++) {
        positions.add(
          TerminalVisualProfile.terminalOffset(
            modelType: entry.key,
            size: entry.value.$1,
            index: index,
            count: entry.value.$2,
          ),
        );
      }
      expect(positions.length, entry.value.$2, reason: entry.key);
    }
  });

  test('C14 contactor terminal order matches topology contracts', () {
    final F9PaletteDefinition ac1 = f9PaletteCatalog.singleWhere(
      (F9PaletteDefinition item) => item.modelType == 'contactor_ac1',
    );
    expect(
      ac1.terminals.map((F9PaletteTerminalSpec item) => item.label),
      <String>['1L1', '2T1', 'A1', 'A2'],
    );

    final F9PaletteDefinition ac3 = f9PaletteCatalog.singleWhere(
      (F9PaletteDefinition item) => item.modelType == 'contactor_3p',
    );
    expect(
      ac3.terminals.map((F9PaletteTerminalSpec item) => item.label),
      <String>['1L1', '3L2', '5L3', '2T1', '4T2', '6T3', 'A1', 'A2'],
    );
  });
}
