import 'package:electrosim/f9_component_palette.dart';
import 'package:electrosim/main.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/regression_fixture.dart';

void main() {
  for (final ElectricalMode mode in ElectricalMode.values) {
    testWidgets('physical instruments appear under Voir tous in ${mode.name}',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final List<String> chosen = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: F9ComponentPalette(
              mode: mode,
              onStatus: (_) {},
              onQuickAdd: (definition) => chosen.add(definition.keyName),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // In the compact quick list the default five stay unchanged.
      expect(find.byKey(const Key('palette-item-instrument-voltmeter')),
          findsNothing);
      expect(find.byKey(const Key('palette-item-instrument-ammeter')),
          findsNothing);
      await tester.tap(find.byKey(const Key('palette-show-all')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('palette-item-instrument-voltmeter')),
          findsOneWidget);
      expect(find.byKey(const Key('palette-item-instrument-ammeter')),
          findsOneWidget);
      await tester.tap(find.byKey(
          const Key('palette-quick-add-instrument-voltmeter')));
      await tester.pumpAndSettle();
      expect(chosen, <String>['instrument-voltmeter']);
    });

    testWidgets('instrument category exists without text search in ${mode.name}',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: F9ComponentPalette(
              mode: mode,
              onStatus: (_) {},
              onQuickAdd: (_) {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('palette-category-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Instruments de mesure').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('palette-item-instrument-voltmeter')),
          findsOneWidget);
      expect(find.byKey(const Key('palette-item-instrument-ammeter')),
          findsOneWidget);
    });
  }

  for (final (String keyName, InstrumentKind kind) in <(String, InstrumentKind)>[
    ('instrument-voltmeter', InstrumentKind.voltmeter),
    ('instrument-ammeter', InstrumentKind.ammeter),
  ]) {
    testWidgets('Voir tous places physical ${kind.name} on the actual board',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: F9WorkspaceDemoPage(
          initialCircuit: buildRegressionFixtureCircuit(),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('palette-show-all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('palette-quick-add-$keyName')));
      await tester.pumpAndSettle();

      final SimulatorCanvas canvas =
          tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
      expect(canvas.circuit.instruments, hasLength(1));
      expect(canvas.circuit.instruments.single.kind, kind);
      final String id = canvas.circuit.instruments.single.id.value;
      expect(canvas.layout.positionOf(id), isNotNull);
      expect(CircuitGeometryIndex.build(canvas.circuit, canvas.layout)
          .elementRects.containsKey(id), isTrue);
    });
  }
}
