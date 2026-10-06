import 'package:electrosim/main.dart' as app;
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void _desktop(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
}

Future<void> _openSchemaLibrary(WidgetTester tester) async {
  await tester.pumpWidget(const app.ElectroSimApp());
  await tester.tap(find.byKey(const Key('home-design')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('design-schema-library')));
  await tester.pumpAndSettle();
}

Future<void> _openFaultLibrary(WidgetTester tester) async {
  await tester.pumpWidget(const app.ElectroSimApp());
  await tester.tap(find.byKey(const Key('home-maintenance')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('maintenance-fault-library')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('G10B design library exposes the two native V2 schemas', (
    WidgetTester tester,
  ) async {
    _desktop(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _openSchemaLibrary(tester);

    expect(find.byKey(const Key('schema-library-page')), findsOneWidget);
    expect(find.text('Bibliothèque de schémas'), findsOneWidget);
    expect(
      find.byKey(const Key('schema-card-V2-SCHEMA-DC-LAMP-01')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('schema-card-V2-SCHEMA-DC-MOTOR-01')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('schema-preview-V2-SCHEMA-DC-LAMP-01')),
      findsOneWidget,
    );
    expect(find.textContaining('seront gérés'), findsNothing);
    expect(find.byType(SimulatorCanvas), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('G10B schema launch loads the selected CircuitState', (
    WidgetTester tester,
  ) async {
    _desktop(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _openSchemaLibrary(tester);
    await tester.tap(
      find.byKey(const Key('schema-open-V2-SCHEMA-DC-LAMP-01')),
    );
    await tester.pumpAndSettle();

    final SimulatorCanvas canvas = tester.widget<SimulatorCanvas>(
      find.byType(SimulatorCanvas),
    );
    expect(canvas.circuit.circuitId.value, 'v2-schema-dc-lamp-01');
    expect(canvas.circuit.mode, ElectricalMode.dc);
    expect(canvas.circuit.sources, hasLength(1));
    expect(canvas.circuit.components, hasLength(1));
    expect(canvas.circuit.connections, hasLength(2));
    expect(canvas.circuit.metadata['origin'], 'v2-native');
    expect(canvas.circuit.metadata['healthy'], isTrue);
  });

  testWidgets('G10B fault library keeps teacher truth private and launches fault', (
    WidgetTester tester,
  ) async {
    _desktop(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _openFaultLibrary(tester);

    expect(find.byKey(const Key('fault-library-page')), findsOneWidget);
    expect(
      find.byKey(const Key('fault-card-V2-FAULT-DC-LAMP-OPEN-01')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('fault-card-V2-FAULT-DC-MOTOR-RETURN-01')),
      findsOneWidget,
    );
    expect(
      find.text('Le voyant présente une coupure interne.'),
      findsNothing,
    );
    expect(
      find.text('Le conducteur de retour du moteur est absent.'),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const Key('fault-launch-V2-FAULT-DC-LAMP-OPEN-01')),
    );
    await tester.pumpAndSettle();

    final SimulatorCanvas canvas = tester.widget<SimulatorCanvas>(
      find.byType(SimulatorCanvas),
    );
    expect(canvas.circuit.circuitId.value, 'v2-fault-dc-lamp-open-01');
    expect(canvas.circuit.mode, ElectricalMode.dc);
    expect(canvas.circuit.metadata['origin'], 'v2-native');
    expect(canvas.circuit.metadata['autonomousFaultScenario'], isTrue);
    expect(
      canvas.circuit.components.single.condition,
      ComponentCondition.openCircuit,
    );
  });

  testWidgets('G10B search and mode filters operate on product content', (
    WidgetTester tester,
  ) async {
    _desktop(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _openSchemaLibrary(tester);

    await tester.enterText(
      find.byKey(const Key('schema-library-search')),
      'moteur',
    );
    await tester.pump();

    expect(
      find.byKey(const Key('schema-card-V2-SCHEMA-DC-MOTOR-01')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('schema-card-V2-SCHEMA-DC-LAMP-01')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('library-filter-ac1')));
    await tester.pumpAndSettle();
    expect(find.text('Aucun schéma ne correspond aux filtres.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('library-filter-all')));
    await tester.enterText(
      find.byKey(const Key('schema-library-search')),
      '',
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('schema-card-V2-SCHEMA-DC-LAMP-01')),
      findsOneWidget,
    );
  });

  testWidgets('G10B libraries remain usable on compact viewport', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _openFaultLibrary(tester);

    final Finder secondFault = find.byKey(
      const Key('fault-card-V2-FAULT-DC-MOTOR-RETURN-01'),
    );
    await tester.ensureVisible(secondFault);
    await tester.pumpAndSettle();

    expect(secondFault, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
