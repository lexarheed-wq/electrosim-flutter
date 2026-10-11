import 'package:electrosim/f18_physical_instrument_readouts.dart';
import 'package:electrosim/f18_voltmeter_3d_assets.dart';
import 'package:electrosim/f18_voltmeter_controls.dart';
import 'package:electrosim/f18_workspace_page.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/regression_fixture.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    expect(await F18Voltmeter3dAssets.preload(), isTrue);
  });

  testWidgets('tap real physical LIGHT / HOLD / SELECT on the F18 board',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final base = buildRegressionFixtureCircuit();
    final meter = InstrumentInstance(
      id: InstrumentId('meter-controls'),
      kind: InstrumentKind.voltmeter,
      mode: InstrumentMode.voltageDc,
    );
    final circuit = CircuitState(
      circuitId: base.circuitId,
      revision: base.revision,
      mode: base.mode,
      sources: base.sources,
      components: base.components,
      connections: base.connections,
      instruments: [meter],
      probes: [
        ProbeConnection(
          id: ProbeId('meter-controls-v'),
          instrumentId: meter.id,
          port: InstrumentPort.voltOhm,
          terminalId: TerminalId('lamp-in'),
        ),
        ProbeConnection(
          id: ProbeId('meter-controls-com'),
          instrumentId: meter.id,
          port: InstrumentPort.common,
          terminalId: TerminalId('lamp-out'),
        ),
      ],
    );
    final layout = CircuitVisualLayout(
      elementPositions: const {
        'source-24v': Offset(205, 285),
        'switch-1': Offset(415, 285),
        'lamp-1': Offset(635, 285),
        'meter-controls': Offset(440, 520),
      },
      elementSizes: const {
        'source-24v': Size(140, 160),
        'switch-1': Size(90, 140),
        'lamp-1': Size(130, 260),
        'meter-controls': Size(112, 152),
      },
    );
    await tester.pumpWidget(MaterialApp(
      home: F18WorkspacePage(
        initialCircuit: circuit,
        initialVisualLayout: layout,
        initialSelectedElementId: meter.id.value,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 250));

    Finder overlay() => find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is F18PhysicalInstrumentReadouts,
    );
    InstrumentInstance instrument() => tester.widgetList<CustomPaint>(
      find.byType(CustomPaint),
    ).map((w) => w.painter)
      .whereType<CircuitScenePainter>()
      .first.circuit.instruments.single;

    Future<void> tap(F18VoltmeterAction action) async {
      final finder = overlay();
      expect(finder, findsOneWidget);
      final painter = tester.widget<CustomPaint>(finder)
          .painter! as F18PhysicalInstrumentReadouts;
      final rect = painter.screenRect(meter.id.value)!;
      final local = switch (action) {
        F18VoltmeterAction.hold => const Offset(35, 56),
        F18VoltmeterAction.range => const Offset(49, 56),
        F18VoltmeterAction.select => const Offset(63, 56),
        F18VoltmeterAction.light => const Offset(77, 56),
        F18VoltmeterAction.selector => const Offset(53, 91),
      };
      final target = tester.getTopLeft(finder) + Offset(
        rect.left + rect.width * local.dx / 112,
        rect.top + rect.height * local.dy / 152,
      );
      await tester.tapAt(target);
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(instrument().mode, InstrumentMode.voltageDc);
    expect(instrument().settings[F18VoltmeterControls.lightKey], isNull);
    await tap(F18VoltmeterAction.light);
    expect(F18VoltmeterControls.isLit(instrument()), isTrue);
    await tap(F18VoltmeterAction.hold);
    expect(F18VoltmeterControls.isHeld(instrument()), isTrue);
    final hold = instrument().settings[F18VoltmeterControls.heldTextKey];
    expect(hold, isA<String>());
    expect(hold, contains('24'));
    // HOLD release, RANGE and SELECT are tested on the real pointer surface.
    await tap(F18VoltmeterAction.hold);
    expect(F18VoltmeterControls.isHeld(instrument()), isFalse);
    await tap(F18VoltmeterAction.range);
    expect(F18VoltmeterControls.rangeLabel(instrument()), '20 V');
    await tap(F18VoltmeterAction.select);
    expect(instrument().mode, InstrumentMode.voltageAcRms);
    expect(F18VoltmeterControls.isHeld(instrument()), isFalse);
    await tap(F18VoltmeterAction.selector);
    expect(instrument().mode, InstrumentMode.resistance);
    await tap(F18VoltmeterAction.selector);
    expect(instrument().poweredOn, isFalse);
    final scene = tester.widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter).whereType<CircuitScenePainter>().first;
    expect(scene.circuit.connections, hasLength(3));
    expect(scene.circuit.probes, hasLength(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(minutes: 2)));
}
