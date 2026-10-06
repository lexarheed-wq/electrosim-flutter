import 'package:electrosim/f9_ui_context.dart';
import 'package:electrosim/main.dart' as app;
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim_diagnostics/electrosim_diagnostics.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _openContext(WidgetTester tester) async {
  final Finder region = find.byKey(electroSimContextRegionKey);
  final double width =
      tester.view.physicalSize.width / tester.view.devicePixelRatio;
  if (region.evaluate().isEmpty || tester.getRect(region).left >= width) {
    await tester.tap(find.byKey(electroSimContextEdgeKey));
    await tester.pumpAndSettle();
  }
}

void main() {
  test('F18-G9 runtime routes PV diagnostics through EIE', () {
    final CircuitState circuit = CircuitState(
      circuitId: CircuitId('g9-invalid-pv'),
      revision: 9,
      mode: ElectricalMode.pv,
    );

    final ElectroSimRuntimeSnapshot snapshot =
        const ElectroSimRuntimeEngine().evaluate(circuit);

    expect(snapshot.diagnosticsAvailable, isTrue);
    expect(
      snapshot.diagnostics.status,
      DiagnosticReportStatus.evidenceAvailable,
    );
    final Set<EieAdviceCode> codes = snapshot.diagnostics.advice
        .map((EieAdvice item) => item.code)
        .toSet();
    expect(codes, contains(EieAdviceCode.pvMissingArray));
    expect(codes, contains(EieAdviceCode.pvMissingInverter));
    expect(
      snapshot.diagnostics.advice.every(
        (EieAdvice item) => item.evidenceIds.isNotEmpty,
      ),
      isTrue,
    );
  });

  testWidgets('F18-G9 EIE is teacher-only', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: app.F9WorkspaceDemoPage(role: F9UserRole.student),
      ),
    );
    await tester.pumpAndSettle();
    await _openContext(tester);

    expect(find.byKey(const Key('eie-tab')), findsNothing);
    expect(find.text('EIE'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'F18-G9 teacher EIE keeps technical evidence collapsed by default',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final CircuitState circuit = CircuitState(
        circuitId: CircuitId('g9-ui-pv'),
        revision: 9,
        mode: ElectricalMode.pv,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: app.F9WorkspaceDemoPage(initialCircuit: circuit),
        ),
      );
      await tester.pumpAndSettle();
      await _openContext(tester);

      expect(find.byKey(const Key('eie-tab')), findsOneWidget);
      await tester.tap(find.byKey(const Key('eie-tab')));
      await tester.pumpAndSettle();

      expect(find.text('Anomalie étayée détectée'), findsOneWidget);
      expect(
        find.byKey(const Key('eie-advice-pvMissingArray')),
        findsOneWidget,
      );
      final ExpansionTile details = tester.widget<ExpansionTile>(
        find.byKey(const Key('eie-evidence-pvMissingArray')),
      );
      expect(details.initiallyExpanded, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
