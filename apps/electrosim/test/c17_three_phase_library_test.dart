import 'package:electrosim/f17_three_phase_components.dart';
import 'package:electrosim/f18_component_asset_visual.dart';
import 'package:electrosim/f9_component_palette.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('C17 palette contracts match physical terminal counts', () {
    const Map<String, int> expected = <String, int>{
      'motor_3p_6t': 6,
      'load_wye_3p': 4,
      'load_delta_3p': 3,
    };
    for (final MapEntry<String, int> entry in expected.entries) {
      final F9PaletteDefinition item = f9PaletteCatalog.singleWhere(
        (F9PaletteDefinition value) => value.modelType == entry.key,
      );
      expect(item.supportsMode(ElectricalMode.ac3), isTrue);
      expect(item.terminalCount, entry.value);
      expect(
        CoreComponentModelContracts.registry.resolve(entry.key)?.terminalCount,
        entry.value,
      );
    }
  });

  test('C17 motor exposes six distinct physical connection anchors', () {
    const Size size = Size(260, 240);
    final Set<Offset> points = <Offset>{
      for (var index = 0; index < 6; index++)
        TerminalVisualProfile.terminalOffset(
          modelType: 'motor_3p_6t',
          size: size,
          index: index,
          count: 6,
        ),
    };
    expect(points.length, 6);
  });

  testWidgets('C17 three-phase models use native production painter',
      (WidgetTester tester) async {
    const List<(String, Type)> cases = <(String, Type)>[
      ('motor_3p_6t', F17ThreePhaseComponentView),
      ('load_wye_3p', F17ThreePhaseComponentView),
      ('load_delta_3p', F17ThreePhaseComponentView),
    ];

    for (final (String modelType, Type expected) in cases) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: F18ComponentAssetVisual(
              modelType: modelType,
              size: F18ReferenceComponentMetrics.dragSizeFor(modelType),
              energized: true,
              currentA: 5,
              voltageV: 230,
              animationValue: .4,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(expected), findsOneWidget, reason: modelType);
      expect(tester.takeException(), isNull, reason: modelType);
    }
  });
}
